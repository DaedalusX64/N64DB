#!/bin/bash

csv="savetypes.csv"
db="daedalus.db"

#Fetch Savetypes and overrides from Google Sheets

curl -L "https://docs.google.com/spreadsheets/d/1hYV0R_SQxX9kZKZvnBV68V2wDeOx3Xq7puPGSS2ioms/export?format=csv&gid=449260782" -o savetypes.csv
curl -L "https://docs.google.com/spreadsheets/d/1hYV0R_SQxX9kZKZvnBV68V2wDeOx3Xq7puPGSS2ioms/export?format=csv&gid=1324284637" -o overrides.csv

# Create database and table if it doesn't exist
if [[ ! -f "$db" ]]; then
sqlite3 "$db" <<EOF
CREATE TABLE games (
  shasum TEXT PRIMARY KEY,
  game_name TEXT NOT NULL,
  daedcrc TEXT NOT NULL,
  SaveType TEXT NOT NULL,
  country TEXT NOT NULL
);
EOF
fi

reverse_crc() {
  local hex="${1#0x}"  # Remove 0x if present
  echo "${hex:6:2}${hex:4:2}${hex:2:2}${hex:0:2}"
}


clean_name() {
  echo "$1" | cut -f1 -d '('
}

# Loop through ROMs 
for i in Roms/*.z64; do
  # Get SHA1 checksum
  shasum=$(shasum "$i" | cut -f1 -d " ")

  # Process Rom Header, CRC in little endian for now (Need to add compatibility for mixed / little endian roms)
  header=$(xxd -p -c 64 -l 64 "$i")
  crc1=$(reverse_crc "${header:32:8}")
  crc2=$(reverse_crc "${header:40:8}") 
  countrycode="${header:124:2}"

  # Convert to Daedalus CRC
  daed_crc=$crc1$crc2-$countrycode
  
  filename=$(basename "$i")
  romname="${filename%.z64}"

  # Clean game name (strip [brackets] and (parentheses))
  gamename=$(clean_name "$romname")
  gamename_sql=$(echo "$gamename" | sed "s/'/''/g")
 

  # Country detection
  country=$(hexdump -s 62 -n 1 -e '"%c"' "$i" | cut -c1)
  case $country in
    A) country="All";;
    B) country="Brazil";;
    C) country="China";;
    D) country="Germany";;
    E) country="North America";;
    F) country="France";;
    G) country="Gateway 64 (NTSC)";;
    H) country="Netherlands";;
    I) country="Italy";;
    J) country="Japan";;
    K) country="Korea";;
    L) country="Gateway 64 (PAL)";;
    N) country="Canada";;
    P) country="Europe";;
    S) country="Spain";;
    U) country="Australia";;
    W) country="Scandinavia";;
    X|Y|Z) country="Europe";;
    *) [[ "$i" == *"iQue"* ]] && country="China" || country="Unknown";;
  esac

  # Insert into database
  sqlite3 "$db" <<EOF 
INSERT OR IGNORE INTO games (shasum, daedcrc, game_name, SaveType, country)
VALUES ('$shasum', '$daed_crc', '$gamename_sql', 'Unknown', '$country');
EOF

done

# --- UPDATE SaveTypes using partial name match ---
# Skip the header and process each line
tail -n +2 "$csv" | while IFS=',' read -r name savetype; do
    # Strip any extra quotes or whitespace
    name=$(echo "$name" | sed -E 's/^["[:space:]]+|["[:space:]]+$//g')
    savetype=$(echo "$savetype" | sed -E 's/^["[:space:]]+|["[:space:]]+$//g' | sed 's/,$//')

    # Clean brackets from the name
    cleaned_name=$(clean_name "$name")

    # Escape single quotes
    esc_savetype=$(echo "$savetype" | sed "s/'/''/g")
    esc_cleaned_name=$(echo "$cleaned_name" | sed "s/'/''/g")

    if [[ $esc_savetype == "" ]]; then
    esc_savetype="Unknown"
    fi

    # Run the update with a LIKE match
    sqlite3 "$db" <<EOF
UPDATE games
SET SaveType = '$esc_savetype'
WHERE game_name LIKE '%$esc_cleaned_name%';
EOF
done

{
  echo "<html>
  <head>
  <title>Daedalus Test Results $(date)</title>
  </head>
  <body>
  <table border='1'>
  <tr>
  <th>Daedalus header</th>
  <th>Game Name</th>
  <th>Save Type</th>
  <th>Country</th>
  <th>Preview Image</th>
  <th>Gameplay Video</th>
  <th>Debug Output</th>
  </tr>"

sqlite3 -separator $'\t' "$db" \
"SELECT shasum, daedcrc, game_name, SaveType, country FROM games;" |
while IFS=$'\t' read -r shasum daed_crc game savetype country; do
  echo "<tr>"
  echo "<td>$daed_crc</td>"
  echo "<td>$game</td>"
  echo "<td>$savetype</td>"
  echo "<td>$country</td>"
  echo "<td><img src='Image/${shasum}.png' style='width:320px;height:200px;'></td>"
  echo "<td><video width='320' height='200' controls preload='none'><source src='Video/${shasum}.webm' type='video/webm'></video></td>"
cat <<EOF
  <td>
    <div id="log-container-${shasum}">
      <a href="Log/${shasum}.txt" target="_blank">View Log</a><br>
      <pre id="log-${shasum}" style="max-height: 200px; overflow: auto; background: #f0f0f0;"></pre>
    </div>
    <script>
      window.addEventListener("DOMContentLoaded", () => {
        const container = document.getElementById("log-container-${shasum}");
        const preElem = document.getElementById("log-${shasum}");
        fetch("Log/${shasum}.txt")
          .then(res => {
            if (!res.ok) throw new Error("Not found");
            return res.text();
          })
          .then(txt => {
            const lines = txt.trim().split(/\\r?\\n/).slice(-5);
            preElem.textContent = lines.join("\\n");
          })
          .catch(() => {
            container.style.display = "none";
          });
      });
    </script>
  </td>
EOF
  echo "</tr>"
done

echo "</table>
</body>
</html>"
} > index.html
