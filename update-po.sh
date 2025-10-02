#!/bin/bash

# Universal translation management script
# Automatically detects project info and manages translations

SCRIPT_DIR="$(dirname "$(readlink -f "${0}")")"
cd "$SCRIPT_DIR"

# Auto-detect configuration
if [ -f "debian/changelog" ]; then
    APPNAME=$(head -n1 debian/changelog | cut -d' ' -f1)
    VERSION=$(head -n1 debian/changelog | sed 's/.*(\([^)]*\)).*/\1/')
else
    APPNAME=$(basename "$PWD")
    VERSION="unknown"
fi

POTFILE="po/messages.pot"

# Configuration
BUGS_EMAIL="support@minios.dev"
COPYRIGHT_HOLDER="MiniOS Linux"

# Auto-detect languages from existing .po files
if [ -d "po" ]; then
    LANGUAGES=($(find po -maxdepth 1 -name "*.po" -exec basename {} .po \; | sort))
fi

# Default languages if none found
if [ ${#LANGUAGES[@]} -eq 0 ]; then
    LANGUAGES=("ru" "pt" "pt_BR" "it" "id" "fr" "es" "de")
fi

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
        log_warning "Translation template not found, skipping statistics"
        return 1
    fi
    
    log_info "Translation statistics for $APPNAME"
    
    # Get total number of messages
    local total=$(msgcat "$POTFILE" | grep -c '^msgid ' 2>/dev/null || echo "0")
    
    if [ "$total" -eq 0 ]; then
        log_warning "No translatable messages found"
        return 1
    fi
    
    printf "\n%-10s %-8s %-12s %-12s %-8s\n" "Component" "Lang" "Translated" "Fuzzy" "Percent"
    echo "-------------------------------------------------------"
    
    # Program translations
    for lang in "${LANGUAGES[@]}"; do
        local pofile="po/${lang}.po"
        
        if [ -f "$pofile" ]; then
            local stats=$(LANG=C msgfmt --statistics -o /dev/null "$pofile" 2>&1)
            local translated=$(echo "$stats" | grep -o '[0-9]\+ translated' | grep -o '[0-9]\+' || echo "0")
            local fuzzy=$(echo "$stats" | grep -o '[0-9]\+ fuzzy' | grep -o '[0-9]\+' || echo "0")
            local untranslated=$(echo "$stats" | grep -o '[0-9]\+ untranslated' | grep -o '[0-9]\+' || echo "0")
            local percent=0
            
            if [ "$total" -gt 0 ]; then
                percent=$((translated * 100 / total))
            fi
            
            printf "%-10s %-8s %-12s %-12s %-8s%%\n" "Programs" "$lang" "$translated" "$fuzzy" "$percent"
        else
            printf "%-10s %-8s %-12s %-12s %-8s\n" "Programs" "$lang" "missing" "-" "-"
        fi
    done
    
    # Man page translations
    if [ -d "manpages/po" ]; then
        for lang in "${LANGUAGES[@]}"; do
            local man_po_dir="manpages/po/$lang"
            if [ -d "$man_po_dir" ]; then
                local man_translated=0
                local man_fuzzy=0
                local man_total=0
                
                for pofile in "$man_po_dir"/*.po; do
                    if [ -f "$pofile" ]; then
                        local stats=$(LANG=C msgfmt --statistics -o /dev/null "$pofile" 2>&1)
                        local translated=$(echo "$stats" | grep -o '[0-9]\+ translated' | grep -o '[0-9]\+' || echo "0")
                        local fuzzy=$(echo "$stats" | grep -o '[0-9]\+ fuzzy' | grep -o '[0-9]\+' || echo "0")
                        local untranslated=$(echo "$stats" | grep -o '[0-9]\+ untranslated' | grep -o '[0-9]\+' || echo "0")
                        
                        man_translated=$((man_translated + translated))
                        man_fuzzy=$((man_fuzzy + fuzzy))
                        man_total=$((man_total + translated + fuzzy + untranslated))
                    fi
                done
                
                local man_percent=0
                if [ "$man_total" -gt 0 ]; then
                    man_percent=$((man_translated * 100 / man_total))
                fi
                
                if [ "$man_total" -gt 0 ]; then
                    printf "%-10s %-8s %-12s %-12s %-8s%%\n" "Man pages" "$lang" "$man_translated" "$man_fuzzy" "$man_percent"
                fi
            fi
        done
    fi
    
    echo "-------------------------------------------------------"
    log_info "Summary:"
    log_info "  Program messages: $total"
    
    # Add man page summary
    if [ -d "manpages/po" ]; then
        local total_man_messages=0
        for lang in "${LANGUAGES[@]}"; do
            local man_po_dir="manpages/po/$lang"
            if [ -d "$man_po_dir" ]; then
                for pofile in "$man_po_dir"/*.po; do
                    if [ -f "$pofile" ]; then
                        local stats=$(LANG=C msgfmt --statistics -o /dev/null "$pofile" 2>&1)
                        local translated=$(echo "$stats" | grep -o '[0-9]\+ translated' | grep -o '[0-9]\+' || echo "0")
                        local fuzzy=$(echo "$stats" | grep -o '[0-9]\+ fuzzy' | grep -o '[0-9]\+' || echo "0")
                        local untranslated=$(echo "$stats" | grep -o '[0-9]\+ untranslated' | grep -o '[0-9]\+' || echo "0")
                        local file_total=$((translated + fuzzy + untranslated))
                        total_man_messages=$((total_man_messages + file_total))
                    fi
                done
                break # Only count once, not per language
            fi
        done
        if [ "$total_man_messages" -gt 0 ]; then
            log_info "  Man page messages: $total_man_messages"
        fi
    fi
    
    # Show summary of issues
    local has_issues=false
    for lang in "${LANGUAGES[@]}"; do
        local pofile="po/${lang}.po"
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
        log_info "Use 'msgattrib --untranslated po/LANG.po' to see untranslated strings"
        log_info "Use 'msgattrib --only-fuzzy po/LANG.po' to see fuzzy translations"
    fi
}

generate_pot() {
    log_info "Generating translation template for $APPNAME..."
    
    # Specific source files for minios-live project
    local sources="minios-live minios-cmd"
    
    # Check if files exist
    local existing_sources=""
    for file in $sources; do
        if [ -f "$file" ]; then
            existing_sources="$existing_sources $file"
        fi
    done
    
    sources="$existing_sources"
    
    if [ -z "$sources" ]; then
        log_error "No source files found (minios-live, minios-cmd)"
        return 1
    fi
    
    log_info "Found source files: $sources"
    
    # Create po directory
    mkdir -p po
    
    # Auto-detect file types and extract translatable strings
    local python_files=""
    local shell_files=""
    
    # Separate Python and Shell files
    for file in $sources; do
        if [[ "$file" == *.py ]] || head -n1 "$file" 2>/dev/null | grep -q "python"; then
            python_files="$python_files $file"
        else
            shell_files="$shell_files $file"
        fi
    done
    
    # Extract from Python files
    if [ -n "$python_files" ]; then
        xgettext --language=Python \
                --keyword=_ \
                --keyword=N_ \
                --add-comments=TRANSLATORS \
                --from-code=UTF-8 \
                --package-name="$APPNAME" \
                --package-version="$VERSION" \
                --msgid-bugs-address="$BUGS_EMAIL" \
                --copyright-holder="$COPYRIGHT_HOLDER" \
                --output="$POTFILE" \
                $python_files 2>/dev/null || true
    fi
    
    # Extract from Shell files and merge
    if [ -n "$shell_files" ]; then
        if [ -f "$POTFILE" ]; then
            # Merge with existing .pot file
            xgettext --language=Shell \
                    --keyword=_ \
                    --keyword=N_ \
                    --add-comments=TRANSLATORS \
                    --from-code=UTF-8 \
                    --package-name="$APPNAME" \
                    --package-version="$VERSION" \
                    --msgid-bugs-address="$BUGS_EMAIL" \
                    --copyright-holder="$COPYRIGHT_HOLDER" \
                    --join-existing \
                    --output="$POTFILE" \
                    $shell_files 2>/dev/null || true
        else
            # Create new .pot file
            xgettext --language=Shell \
                    --keyword=_ \
                    --keyword=N_ \
                    --add-comments=TRANSLATORS \
                    --from-code=UTF-8 \
                    --package-name="$APPNAME" \
                    --package-version="$VERSION" \
                    --msgid-bugs-address="$BUGS_EMAIL" \
                    --copyright-holder="$COPYRIGHT_HOLDER" \
                    --output="$POTFILE" \
                    $shell_files 2>/dev/null || true
        fi
    fi
    
    # Check if .pot file was created successfully
    if [ -f "$POTFILE" ] && [ -s "$POTFILE" ]; then
        log_success "Translation template generated: $POTFILE"
        return 0
    else
        log_error "Failed to generate translation template"
        return 1
    fi
}

update_po_files() {
    log_info "Updating translation files for languages: ${LANGUAGES[*]}"
    
    if [ ! -f "$POTFILE" ]; then
        log_error "Translation template not found: $POTFILE"
        return 1
    fi
    
    local updated=0
    local created=0
    
    for lang in "${LANGUAGES[@]}"; do
        local pofile="po/${lang}.po"
        
        if [ ! -f "$pofile" ]; then
            log_warning "Creating new translation file for $lang..."
            if msginit --input="$POTFILE" --locale="$lang" --output-file="$pofile" --no-translator 2>/dev/null; then
                # Force UTF-8 encoding for new files
                sed -i 's/charset=CHARSET/charset=UTF-8/' "$pofile"
                sed -i 's/charset=ASCII/charset=UTF-8/' "$pofile"
                log_success "Created: $pofile"
                ((created++))
            else
                log_error "Failed to create: $pofile"
            fi
        else
            if msgmerge --update --backup=off "$pofile" "$POTFILE" 2>/dev/null; then
                log_success "Updated: $pofile"
                ((updated++))
            else
                log_error "Failed to update: $pofile"
            fi
        fi
    done
    
    if [ $created -gt 0 ] || [ $updated -gt 0 ]; then
        log_info "Summary: $created created, $updated updated"
    else
        log_warning "No files were created or updated"
    fi
}

# Update man page translations
update_man_translations() {
    log_info "Updating man page translations"
    
    if [ ! -d "manpages" ] || [ ! -f "manpages/po4a.cfg" ]; then
        log_warning "Man pages directory or po4a.cfg not found, skipping"
        return
    fi
    
    # Check if pandoc is available
    if ! command -v pandoc >/dev/null 2>&1; then
        log_warning "pandoc not found, skipping man page generation"
        return
    fi
    
    # Generate English man pages from markdown
    log_info "Generating English man pages from markdown..."
    local generated=0
    local failed=0
    
    if [ -f "docs/minios-live.1.md" ]; then
        if pandoc -s -t man docs/minios-live.1.md -o manpages/minios-live.1 2>/dev/null; then
            ((generated++))
        else
            ((failed++))
        fi
    fi
    
    if [ -f "docs/minios-cmd.1.md" ]; then
        if pandoc -s -t man docs/minios-cmd.1.md -o manpages/minios-cmd.1 2>/dev/null; then
            ((generated++))
        else
            ((failed++))
        fi
    fi
    
    if [ -f "docs/condinapt.1.md" ]; then
        if pandoc -s -t man docs/condinapt.1.md -o manpages/condinapt.1 2>/dev/null; then
            ((generated++))
        else
            ((failed++))
        fi
    fi
    
    if [ -f "docs/condinapt-minios.7.md" ]; then
        if pandoc -s -t man docs/condinapt-minios.7.md -o manpages/condinapt-minios.7 2>/dev/null; then
            ((generated++))
        else
            ((failed++))
        fi
    fi
    
    if [ $generated -eq 0 ]; then
        log_warning "No man pages were generated"
        return
    fi
    
    log_success "Generated $generated man page(s)"
    [ $failed -gt 0 ] && log_warning "Failed to generate $failed man page(s)"
    
    # Create necessary directories for po4a
    for lang in "${LANGUAGES[@]}"; do
        mkdir -p "manpages/po/$lang"
    done
    mkdir -p "manpages/pot"
    
    # Generate translations with po4a
    cd manpages
    if po4a --keep 0 --package-name "$APPNAME" po4a.cfg 2>/dev/null; then
        log_success "Man page translations updated"
    else
        log_warning "Failed to update man page translations with po4a"
    fi
    cd ..
}

# Main execution
log_info "Starting translation workflow for $APPNAME (version $VERSION)"
log_info "Languages: ${LANGUAGES[*]}"

if generate_pot; then
    update_po_files
    update_man_translations
    show_stats
    log_success "Translation workflow completed"
else
    log_error "Workflow failed during template generation"
    exit 1
fi
