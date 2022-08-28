#!/bin/sh

# Try to find out kernel modules with large total memory allocation during loading.
# For large slab allocation, it will fall into buddy, also not trace "mm_page_free"
# considering large free is quite rare for module_init, thus saving tons of events
# to avoid trace data overwritten.
#
# Therefore, tracing "mm_page_alloc"alone should be enough for the purpose.

# "sys/kernel/tracing" has the priority if exists.
get_trace_base() {
    # trace access through debugfs would be obsolete if "/sys/kernel/tracing" is available.
    if [ -d "/sys/kernel/tracing" ]; then
        echo "/sys/kernel"
    else
        echo "/sys/kernel/debug"
    fi
}

# We want to enable these trace events.
get_want_events() {
    echo "module:module_put module:module_load kmem:mm_page_alloc"
}

get_event_filter() {
    echo "comm == systemd-udevd || comm == modprobe || comm == insmod"
}

is_trace_ready() {
    local trace_base want_events current_events

    trace_base=$(get_trace_base)
    ! [ -f "$trace_base/tracing/trace" ] && return 1

    [ "$(cat $trace_base/tracing/tracing_on)" -eq 0 ] && return 1

    # Also check if trace events were properly setup.
    want_events=$(get_want_events)
    current_events=$(echo $(cat $trace_base/tracing/set_event))
    [ "$current_events" != "$want_events" ] && return 1

    return 0
}

prepare_trace() {
    local trace_base

    trace_base=$(get_trace_base)
    # old debugfs interface case.
    if ! [ -d "$trace_base/tracing" ]; then
        mount none -t debugfs $trace_base
    # new tracefs interface case.
    elif ! [ -f "$trace_base/tracing/trace" ]; then
        mount none -t tracefs "$trace_base/tracing"
    fi

    if ! [ -f "$trace_base/tracing/trace" ]; then
        echo "WARN: Mount trace failed for kernel module memory analyzing."
        return 1
    fi

    # Active all the wanted trace events.
    echo "$(get_want_events)" > $trace_base/tracing/set_event

    # There are three kinds of known applications for module loading:
    # "systemd-udevd", "modprobe" and "insmod".
    # Set them as the global events filter.
    # NOTE: Some kernel may not support this format of filter, anyway
    #       the operation will fail and it doesn't matter.
    echo "$(get_event_filter)" > $trace_base/tracing/events/kmem/filter 2>&1
    echo "$(get_event_filter)" > $trace_base/tracing/events/module/filter 2>&1

    # Set the number of comm-pid if supported.
    if [ -f "$trace_base/tracing/saved_cmdlines_size" ]; then
        # Thanks to filters, 4096 is big enough(also well supported).
        echo 4096 > $trace_base/tracing/saved_cmdlines_size
    fi

    # Enable and clear trace data for the first time.
    echo 1 > $trace_base/tracing/tracing_on
    echo > $trace_base/tracing/trace
    echo "Prepare trace success."
    return 0
}

order_to_pages()
{
    local pages=1
    local order=$1

    while [ "$order" != 0 ]; do
        order=$((order-1))
        pages=$(($pages*2))
	done

    echo $pages
}

parse_trace_data() {
    local module_name tmp_eval pages

    cat "$(get_trace_base)/tracing/trace" | while read pid cpu flags ts function args
    do
        # Skip comment lines
        if [ "$pid" = "#" ]; then
            continue
        fi

        pid=${pid##*-}
        function=${function%:}
        if [ "$function" = "module_load" ]; then
            # One module is being loaded, save the task pid for tracking.
            # Remove the trailing after whitespace, there may be the module flags.
            module_name=${args%% *}
            # Mark current_module to track the task.
            eval current_module_$pid="$module_name"
            tmp_eval=$(eval echo '${module_loaded_'${module_name}'}')
            if [ -n "$tmp_eval" ]; then
                echo "WARN: \"$module_name\" was loaded multiple times!"
            fi
            eval unset module_loaded_$module_name
            eval nr_alloc_pages_$module_name=0
            continue
        fi

        module_name=$(eval echo '${current_module_'${pid}'}')
        if [ -z "$module_name" ]; then
            continue
        fi

        # Once we get here, the task is being tracked(is loading a module).
        if [ "$function" = "module_put" ]; then
            # Mark the module as loaded when the first module_put event happens after module_load.
            tmp_eval=$(eval echo '${nr_alloc_pages_'${module_name}'}')
            echo "$tmp_eval pages consumed by \"$module_name\""
            eval module_loaded_$module_name=1
            # Module loading finished, so untrack the task.
            eval unset current_module_$pid
            eval unset nr_alloc_pages_$module_name
            continue
        fi

        if [ "$function" = "mm_page_alloc" ]; then
            # Get order first, then convert to actual pages.
            pages=$(echo $args | sed -e 's/.*order=\([0-9]*\) .*/\1/')
            pages=$(order_to_pages "$pages")
            tmp_eval=$(eval echo '${nr_alloc_pages_'${module_name}'}')
            eval nr_alloc_pages_$module_name="$(($tmp_eval+$pages))"
        fi
    done
}

cleanup_trace() {
    local trace_base

    if is_trace_ready; then
        trace_base=$(get_trace_base)
        echo 0 > $trace_base/tracing/tracing_on
        echo > $trace_base/tracing/trace
        echo > $trace_base/tracing/set_event
        echo 0 > $trace_base/tracing/events/kmem/filter
        echo 0 > $trace_base/tracing/events/module/filter
    fi
}

show_usage() {
    echo "Find out kernel modules with large memory consumption during loading based on trace."
    echo "Usage:"
    echo "1) run it first to setup trace."
    echo "2) run again to parse the trace data if any."
    echo "3) run with \"--cleanup\" option to cleanup trace after use."
}

if [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

if [ "$1" = "--cleanup" ]; then
    cleanup_trace
    exit 0
fi

if is_trace_ready ; then
    echo "tracekomem - Rough memory consumption by loading kernel modules (larger value with better accuracy)"
    parse_trace_data
else
    prepare_trace
fi

exit $?
