#!/bin/sh
# Grants (or revokes) the paid Dark entitlement for a Firebase Auth uid,
# using the Firebase CLI's own login. Wire a real purchase backend later;
# until then this is how a tester gets in.
#   tool/grant_dark.sh <uid> [true|false]
set -e
UID_="$1"; VAL="${2:-true}"
[ -z "$UID_" ] && { echo "usage: $0 <uid> [true|false]"; exit 1; }
PROJECT=$(python3 -c "import json;print(json.load(open('.firebaserc'))['projects']['default'])")
TOKEN=$(python3 - <<'PY'
import json,os,urllib.request,urllib.parse
tok=json.load(open(os.path.expanduser('~/.config/configstore/firebase-tools.json')))['tokens']
data=urllib.parse.urlencode({'client_id':'563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
 'client_secret':'j9iVZfS8kkCEFUPaAeJV0sAi','refresh_token':tok['refresh_token'],'grant_type':'refresh_token'}).encode()
print(json.load(urllib.request.urlopen('https://oauth2.googleapis.com/token',data))['access_token'])
PY
)
curl -s -X PATCH -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"fields\":{\"dark\":{\"booleanValue\":$VAL}}}" \
  "https://firestore.googleapis.com/v1/projects/$PROJECT/databases/(default)/documents/entitlements/$UID_?updateMask.fieldPaths=dark" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print('entitlements/$UID_ dark =', d.get('fields',{}).get('dark',d))"
