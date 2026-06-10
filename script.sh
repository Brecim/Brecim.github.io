#!/usr/bin/env bash

# --- KONFIGURACE ---
SOURCES=("/cesta/k/zdroji") # Nezapomeňte změnit cestu k zdrojové složce!
DEST="/cesta/k/zaloze" # Nezapomeňte změnit cestu k cílové složce!
PREFIX="$(hostname)-backup"
KEEP=7
RSYNC_OPTS="-aHAX --delete --info=progress2"

# --- KONTROLA A PŘÍPRAVA ---
if [ ! -d "$DEST" ]; then
  echo "Chyba: Cílová složka $DEST neexistuje." >&2
  exit 2
fi

TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"
TMP_DEST="${DEST}/${PREFIX}-${TIMESTAMP}.inprogress"
FINAL_DEST="${DEST}/${PREFIX}-${TIMESTAMP}"

# --- NALEZENÍ POSLEDNÍ ZÁLOHY PRO HARDLINKY ---
LATEST_BACKUP=$(ls -1dt "${DEST}/${PREFIX}-"* 2>/dev/null | grep -v "\.inprogress$" | head -n 1)

if [ -n "$LATEST_BACKUP" ]; then
  RSYNC_OPTS="$RSYNC_OPTS --link-dest=$LATEST_BACKUP"
fi

# --- PROCES ZÁLOHOVÁNÍ ---
mkdir -p "$TMP_DEST"

for src in "${SOURCES[@]}"; do
  if [ ! -e "$src" ]; then
    echo "Varování: Zdroj $src neexistuje – přeskakuji."
    continue
  fi
  rsync $RSYNC_OPTS "$src" "$TMP_DEST/"
done

mv "$TMP_DEST" "$FINAL_DEST"

# --- ROTACE ZÁLOH ---
cd "$DEST"
ls -1dt ${PREFIX}-* 2>/dev/null | grep -v "\.inprogress$" | sed -n "$((KEEP+1)),\$p" | while read -r old; do
  [ -z "$old" ] && break
  rm -rf -- "$old"
done

echo "Záloha dokončena: $FINAL_DEST"
exit 0
