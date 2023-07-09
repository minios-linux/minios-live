#!/bin/bash

# Define a function to check if the Stop button has been pressed
check_stop_button() {
    while true; do
        # Check if the Stop button has been pressed in the yad window
        if ! kill -0 $yad_pid 2>/dev/null; then
            # If the Stop button has been pressed, exit the script
            kill -s SIGTERM $$
            exit 0
        fi

        sleep 1
    done
}

# Define a function to check the run time in the background
check_run_time() {
    while true; do
        # Check if the run time has expired
        current_time=$(date +%s)
        if (( current_time - start_time >= run_time )); then
            # If the run time has expired, exit the script
            kill $yad_pid 2>/dev/null
            kill -s SIGTERM $$
            exit 0
        fi

        sleep 1
    done
}

# Define a function to handle the SIGTERM signal
sigterm_handler() {
    exit 0
}

# Set up a trap to catch the SIGTERM signal and call the sigterm_handler function
trap sigterm_handler SIGTERM

# Get a list of open windows and save it in a variable
windows=$(wmctrl -l | awk '{$1=$2=$3=""; print $0}' | sed 's/^ //')

# Display a yad form window to select the window, wait time, and run time of the script
form_output=$(yad --form --field="Window:CB" --field="Wait time (seconds):NUM" --field="Randomization range (seconds):NUM" --field="Run time (HH:MM:SS):S" --title="Select options" "$(echo ${windows//$'\n'/!})" "90" "30" "01:00:00")

# Split the form output into separate variables
selected_window=$(echo $form_output | awk -F '|' '{print $1}')
wait_time=$(echo $form_output | awk -F '|' '{print $2}')
randomization_range=$(echo $form_output | awk -F '|' '{print $3}')
run_time_str=$(echo $form_output | awk -F '|' '{print $4}')

# Convert the run time from HH:MM:SS format to seconds
run_time=$(date -u -d "1970-01-01 $run_time_str" +"%s")

# Get the ID of the selected window
window_id=$(wmctrl -l | grep "$selected_window" | awk '{print $1}')

# Start counting the run time of the script
start_time=$(date +%s)

# Display a yad window with a timer and a Stop button for stopping the script
(
    while true; do
        # Update the timer and progress bar in yad window 
        current_time=$(date +%s)
        remaining_time=$((run_time - (current_time - start_time)))
        echo "# Time remaining: $(date -u -d @$remaining_time +'%H:%M:%S')"
        echo "$(((current_time - start_time) * 100 / run_time))"

        sleep 1 
    done 
) | yad --progress --auto-close --button="Stop:0" --title="Progress" &

# Save the PID of yad process 
yad_pid=$!

# Run the check_run_time function in the background
check_run_time &

# Run the check_stop_button function in the background
check_stop_button &

# Press Scroll Lock key every $wait_time seconds 
while true; do

    # Get ID of current active window 
    active_window=$(xdotool getactivewindow)

    # Check if selected window is minimized 
    if xprop -id $window_id | grep -q "window state: Iconic"; then
        # If window is minimized, unminimize it 
        wmctrl -ia $window_id

        # Press Scroll Lock key 
        xdotool key "Scroll_Lock"

        # Minimize window again 
        wmctrl -ir $window_id -b add,hidden

        # Return to previous active window without changing window order 
        xdotool windowfocus --sync $active_window
    else
        # Switch to selected window without changing window order 
        xdotool windowfocus --sync $window_id

        # Press Scroll Lock key 
        xdotool key "Scroll_Lock"

        # Return to previous active window without changing window order 
        xdotool windowfocus --sync $active_window
    fi

    # Randomly select wait time within specified range 
    randomized_wait_time=$((wait_time - randomization_range / 2 + RANDOM % randomization_range))

    sleep $randomized_wait_time
done
