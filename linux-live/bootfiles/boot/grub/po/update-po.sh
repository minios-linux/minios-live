#!/bin/bash

# GRUB Translation Update Script
# Automatically updates all .po files from the messages.pot template
# Based on the main MiniOS update-po.sh script

SCRIPT_DIR="$(dirname "$(readlink -f "${0}")")"
cd "$SCRIPT_DIR"

# Configuration
APPNAME="MiniOS GRUB"
VERSION="latest"
POTFILE="messages.pot"
BUGS_EMAIL="support@minios.dev"
COPYRIGHT_HOLDER="MiniOS Linux"

# Auto-detect languages from existing .po files
LANGUAGES=($(find . -maxdepth 1 -name "*.po" -exec basename {} .po \; | sort))

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_stats() {
    if [ ! -f "$POTFILE" ]; then
        log_warning "Translation template not found: $POTFILE"
        return 1
    fi
    
    log_info "Translation statistics for $APPNAME:"
    
    # Get total number of messages
    local total=$(msgcat "$POTFILE" | grep -c '^msgid ' 2>/dev/null || echo "0")
    
    if [ "$total" -eq 0 ]; then
        log_warning "No translatable messages found in $POTFILE"
        return 1
    fi
    
    printf "%-8s %-12s %-12s %-8s\n" "Lang" "Translated" "Fuzzy" "Percent"
    echo "----------------------------------------"
    
    for lang in "${LANGUAGES[@]}"; do
        local pofile="${lang}.po"
        
        if [ -f "$pofile" ]; then
            local stats=$(msgfmt --statistics -o /dev/null "$pofile" 2>&1)
            local translated=$(echo "$stats" | grep -o '[0-9]\+ translated' | grep -o '[0-9]\+' || echo "0")
            local fuzzy=$(echo "$stats" | grep -o '[0-9]\+ fuzzy' | grep -o '[0-9]\+' || echo "0")
            local percent=0
            
            if [ "$total" -gt 0 ]; then
                percent=$((translated * 100 / total))
            fi
            
            printf "%-8s %-12s %-12s %-8s%%\n" "$lang" "$translated" "$fuzzy" "$percent"
        else
            printf "%-8s %-12s %-12s %-8s\n" "$lang" "missing" "-" "-"
        fi
    done
    
    echo "----------------------------------------"
    log_info "Total messages: $total"
    
    # Show summary of issues
    local has_issues=false
    for lang in "${LANGUAGES[@]}"; do
        local pofile="${lang}.po"
        if [ -f "$pofile" ]; then
            local untranslated_file=$(msgattrib --untranslated "$pofile" 2>/dev/null)
            local fuzzy_file=$(msgattrib --only-fuzzy "$pofile" 2>/dev/null)
            
            local untranslated=0
            local fuzzy=0
            
            if [ -n "$untranslated_file" ]; then
                untranslated=$(echo "$untranslated_file" | grep -c '^msgid ' 2>/dev/null || echo "0")
            fi
            
            if [ -n "$fuzzy_file" ]; then
                fuzzy=$(echo "$fuzzy_file" | grep -c '^msgid ' 2>/dev/null || echo "0")
            fi
            
            if [ "$untranslated" -gt 0 ] || [ "$fuzzy" -gt 0 ]; then
                if [ "$has_issues" = false ]; then
                    echo
                    log_info "Translation issues found:"
                    has_issues=true
                fi
                
                local issues=""
                [ "$untranslated" -gt 0 ] && issues="$untranslated untranslated"
                [ "$fuzzy" -gt 0 ] && issues="$issues${issues:+, }$fuzzy fuzzy"
                
                echo "  $lang: $issues"
            fi
        fi
    done
    
    if [ "$has_issues" = true ]; then
        echo
        log_info "Use 'msgattrib --untranslated LANG.po' to see untranslated strings"
        log_info "Use 'msgattrib --only-fuzzy LANG.po' to see fuzzy translations"
    fi
}

update_po_files() {
    log_info "Updating .po files for languages: ${LANGUAGES[*]}"
    
    if [ ! -f "$POTFILE" ]; then
        log_error "Translation template not found: $POTFILE"
        log_info "Expected file: $PWD/$POTFILE"
        return 1
    fi
    
    local updated=0
    local created=0
    local failed=0
    
    for lang in "${LANGUAGES[@]}"; do
        local pofile="${lang}.po"
        
        if [ ! -f "$pofile" ]; then
            log_warning "Creating new translation file for $lang..."
            if msginit --input="$POTFILE" --locale="$lang" --output-file="$pofile" --no-translator 2>/dev/null; then
                # Force UTF-8 encoding for new files
                sed -i 's/charset=CHARSET/charset=UTF-8/' "$pofile"
                sed -i 's/charset=ASCII/charset=UTF-8/' "$pofile"
                
                # Update header information
                sed -i "s/PACKAGE VERSION/$APPNAME/" "$pofile"
                sed -i "s/YEAR THE PACKAGE'S COPYRIGHT HOLDER/$(date +%Y) $COPYRIGHT_HOLDER/" "$pofile"
                sed -i "s/FIRST AUTHOR <EMAIL@ADDRESS>, YEAR./MiniOS Team <$BUGS_EMAIL>, $(date +%Y)./" "$pofile"
                
                log_success "Created: $pofile"
                ((created++))
            else
                log_error "Failed to create: $pofile"
                ((failed++))
            fi
        else
            log_info "Updating $lang translations..."
            if msgmerge --update --backup=off "$pofile" "$POTFILE" 2>/dev/null; then
                log_success "Updated: $pofile"
                ((updated++))
            else
                log_error "Failed to update: $pofile"
                ((failed++))
            fi
        fi
    done
    
    log_info "Summary: $created created, $updated updated, $failed failed"
    
    if [ $failed -gt 0 ]; then
        return 1
    fi
    
    return 0
}

validate_po_files() {
    log_info "Validating .po files..."
    
    local errors=0
    for lang in "${LANGUAGES[@]}"; do
        local pofile="${lang}.po"
        
        if [ -f "$pofile" ]; then
            if ! msgfmt --check "$pofile" 2>/dev/null; then
                log_error "Validation failed for $pofile"
                ((errors++))
            fi
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_success "All .po files are valid"
        return 0
    else
        log_error "$errors .po files have validation errors"
        return 1
    fi
}

show_help() {
    echo "GRUB Translation Update Script"
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -s, --stats     Show translation statistics only"
    echo "  -v, --validate  Validate .po files only"
    echo "  -u, --update    Update .po files from .pot template (default)"
    echo ""
    echo "This script updates GRUB translation files (.po) from the messages.pot template."
    echo "It automatically detects all existing language files and updates them."
    echo ""
    echo "Languages found: ${LANGUAGES[*]}"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -s|--stats)
        show_stats
        exit 0
        ;;
    -v|--validate)
        validate_po_files
        exit $?
        ;;
    -u|--update|"")
        # Default action - update files
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac

# Main execution
log_info "Starting GRUB translation update workflow..."
log_info "Working directory: $PWD"
log_info "Languages detected: ${LANGUAGES[*]}"

if [ ${#LANGUAGES[@]} -eq 0 ]; then
    log_error "No .po files found in current directory"
    log_info "Expected files like: ru_RU.po, de_DE.po, etc."
    exit 1
fi

if update_po_files; then
    show_stats
    validate_po_files
    log_success "GRUB translation update completed successfully!"
else
    log_error "Translation update failed"
    exit 1
fi