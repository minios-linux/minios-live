#!/bin/bash
# Define the directory where the script is located (for running from any folder)
SCRIPT_DIR="$(dirname "$(readlink -f "${0}")")"

# Script for updating messages.pot and generating .po translation files
# for the minios-live and minios-cmd scripts.

LANGUAGES=("ru" "pt" "pt_BR" "it" "id" "fr" "es" "de")
SCRIPTS=("minios-live" "minios-cmd")
MESSAGES="po/messages.pot"

echo "Generating translation template (messages.pot) for scripts..."
xgettext --language=Shell --output="$MESSAGES" "${SCRIPTS[@]}"

# For each language
for lang in "${LANGUAGES[@]}"; do
    POFILE="po/${lang}.po"
    if [[ ! -f "$POFILE" ]]; then
        echo "Initializing translation file for language $lang..."
        msginit --input="$MESSAGES" --locale="$lang" --output-file="$POFILE" --no-translator
    else
        echo "Updating translation file for language $lang..."
        msgmerge --update "$POFILE" "$MESSAGES"
    fi
done

echo "PO files generation automation completed."
