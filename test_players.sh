#!/bin/bash

# Lista 3 testowych filmów o różnej specyfice (lektor AI, napisy, różne hostingi)
URLS=(
    "https://ekino.ws/movie/show/naznaczony-wyjscie-z-mrocznego-wymiaru-hd-insidious-out-of-the-further-2026-lektor/42720"
    "https://ekino.ws/movie/show/the-cycle-hd-2026-lektor-ai/43210"
    "https://ekino.ws/movie/show/mumia-hd-napisy-the-mummy-2017-napisy/20101"
)

for URL in "${URLS[@]}"; do
    echo "================================================================================"
    echo "ANALIZA: $URL"
    echo "================================================================================"
    
    HTML=$(curl -sL -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$URL")
    
    echo -e "\n--- [TYTUŁ I OPIS] ---"
    echo "$HTML" | grep -o -E '<h1 class="title">[^<]+' | head -n 1
    echo "$HTML" | grep -A 2 'class="descriptionMovie"' | sed -e 's/<[^>]*>//g' | tr -s ' ' | head -n 3
    
    echo -e "\n--- [ZAKŁADKI PLAYERÓW (Wersje / Ikony)] ---"
    echo "$HTML" | grep -A 10 -B 1 'role="tablist"' | grep -E '(href=|title=)' | head -n 25
    
    echo -e "\n--- [KONTENERY TAB-PANE / SKRYPTY HOSTA I ID] ---"
    echo "$HTML" | grep -C 3 -E '(/watch/f/|src="/watch/|fplayer_|freePlayerClickf_)' | head -n 30
    echo -e "\n"
done
