Tento návod vás provede vytvořením robustního zálohovacího skriptu v Bashi, který využívá nástroj `rsync` pro efektivní kopírování, podporuje verzování (rotaci) záloh a ošetřuje nedokončené přenosy.

---

Aby mohl tento skript správně fungovat, budete potřebovat následující softwarové vybavení. Většina z těchto nástrojů je v Linuxu standardní součástí systému, ale je dobré si ověřit jejich přítomnost.

# Potřebný software:

1.  **Textový editor (nano):**
    *   Budeme v návodě používat textový editor `nano`, ale samozřejmě lze použít jakýkoliv jiný editor.
    *   Pokud jej nemáte, nainstalujete jej příkazem:
        *   *Debian/Ubuntu/Mint:* `sudo apt install nano`
        *   *Fedora/RHEL/CentOS:* `sudo dnf install nano`
        *   *Arch Linux:* `sudo pacman -S nano`
2.  **rsync:**
    *   **Klíčový nástroj** pro samotné kopírování a synchronizaci souborů.
    *   Pokud jej nemáte, nainstalujete jej příkazem:
        *   *Debian/Ubuntu/Mint:* `sudo apt install rsync`
        *   *Fedora/RHEL/CentOS:* `sudo dnf install rsync`
        *   *Arch Linux:* `sudo pacman -S rsync`

## Jak ověřit, zda je vše připraveno?
Stačí do terminálu napsat:
```bash
rsync --version
```
Pokud se zobrazí verze programu, je vše v pořádku a můžete skript začít používat.

# Návod

## 1. Vytvoření a otevření souboru
Nejprve v terminálu vytvoříme nový soubor pro náš skript a otevřeme jej v textovém editoru (např. `nano`):

```bash
touch zaloha_skript.sh
nano zaloha_skript.sh
```

## 2. Definice proměnných a konfigurace
Do souboru vložíme úvodní řádku (shebang) a definujeme parametry zálohování.

```bash
#!/usr/bin/env bash

# --- KONFIGURACE ---
# Cesty ke složkám, které chceme zálohovat (vložené do pole)
SOURCES=("/home/user/test")

# Cesta, kam se zálohy budou ukládat
DEST="/home/user/zaloha"

# Prefix názvu zálohy a počet zachovaných verzí
PREFIX="$(hostname)-backup"
KEEP=7

# Parametry pro RSYNC
# -a: archivní (zachová oprávnění, časy, rekurze)
# -H: zachová hardlinky
# -A: zachová ACL (přístupová práva)
# -X: zachová rozšířené atributy
# --delete: smaže v cíli soubory, které už nejsou ve zdroji
RSYNC_OPTS="-aHAX --delete --info=progress2"
```

## 3. Kontrola prostředí a příprava názvů
Skript musí ověřit, zda cílová složka existuje, a připravit si časové razítko pro unikátní název každé zálohy.

```bash
# Kontrola existence cílové složky
if [ ! -d "$DEST" ]; then
  echo "Chyba: Cílová složka $DEST neexistuje." >&2
  exit 2
fi

# Vytvoření časového razítka a názvů složek
TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"
# Dočasná složka pro probíhající zálohu
TMP_DEST="${DEST}/${PREFIX}-${TIMESTAMP}.inprogress"
# Konečný název po úspěšném dokončení
FINAL_DEST="${DEST}/${PREFIX}-${TIMESTAMP}"
```

## 4. Samotné zálohování (Smyčka a Rsync)
V této části vytvoříme dočasnou složku a postupně do ní pomocí rsync zkopírujeme všechny definované zdroje.

```bash
mkdir -p "$TMP_DEST"

for src in "${SOURCES[@]}"; do
  if [ ! -e "$src" ]; then
    echo "Varování: Zdroj $src neexistuje – přeskakuji."
    continue
  fi
  
  # Spuštění kopírování
  rsync $RSYNC_OPTS "$src" "$TMP_DEST/"
done

# Po úspěšném dokončení přejmenujeme dočasnou složku na finální
mv "$TMP_DEST" "$FINAL_DEST"
```

## 5. Rotace záloh (Mazání starých verzí)
Aby disk nepřetekl, ponecháme pouze nastavený počet nejnovějších záloh (proměnná `KEEP`).

```bash
cd "$DEST"
# Seřadí složky podle času (nejnovější nahoře) a vybere ty k smazání
ls -1dt ${PREFIX}-* 2>/dev/null | sed -n "$((KEEP+1)),\$p" | while read -r old; do
  if [ -n "$old" ]; then
    echo "Mažu starou zálohu: $old"
    rm -rf -- "$old"
  fi
done

echo "Záloha dokončena: $FINAL_DEST"
exit 0
```

---

# Jak skript uložit a spustit

1.  **Uložení:** V editoru `nano` stiskněte `Ctrl+S` (uložit) a poté `Ctrl+X` (odejít).
2.  **Práva ke spuštění:** Aby bylo možné soubor spustit jako program, musíte mu přidat oprávnění:
    ```bash
    chmod +x zaloha_skript.sh
    ```
3.  **Spuštění:** Skript nyní můžete spustit příkazem:
    ```bash
    ./zaloha_skript.sh
    ```

# Celý skript pro zkopírování:

```bash
#!/usr/bin/env bash

# --- KONFIGURACE ---
SOURCES=("/home/user/test")
DEST="/home/user/zaloha"
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
ls -1dt ${PREFIX}-* 2>/dev/null | sed -n "$((KEEP+1)),\$p" | while read -r old; do
  [ -z "$old" ] && break
  rm -rf -- "$old"
done

echo "Záloha dokončena: $FINAL_DEST"
exit 0
```

### Nastavení cron-u pomocí crontabu

#### Co je crontab?
- Soubory crontab určují, které příkazy se mají spouštět a kdy.
- Na nastavení pravidelného spuštění příkazu přidáme nový řádek dle formátu:

```
minuty hodiny den_v_mesici mesic den_v_tydnu prikaz
```

**Rozsahy času**
  - minuty: 0–59
  - hodiny: 0–23
  - den_v_mesici: 1–31
  - mesic: 1–12 (nebo zkratky Jan–Dec)
  - den_v_tydnu: 0–7 (0 a 7 = neděle nebo zkratky Sun–Sat)

**Příklady**
- Každou noc v 01:00:
  ```
  0 1 * * * /cesta/k/night_job.sh
  ```
- Každou neděli v 04:30:
  ```
  30 4 * * 0 /cesta/k/weekly.sh
  ```

Abychom mohli nastavit pravidelné spuštění příkazu, musíme otevřít _crontab_:

```
crontab -e
```


Objeví se textový editor, který by měl vypadat takhle:

![](obrazky/prazdny_crontab.png)


---
[1]: https://crontab.guru
[2]: https://duck.ai
[3]: https://gemini.google.com
