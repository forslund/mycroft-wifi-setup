#!/usr/bin/env bash

set -eE

source ./utils.sh
check_args $@
get_version $@

rm -rf build/ dist/

[ "$1" = "clean" ] && exit 0

mkdir dist
git clone https://github.com/MycroftAI/mycroft-core build -b dev --single-branch --depth 1

if [ "$1" = "release" ]; then
	tag=release/v$version
	if ! git tag | grep -q $tag; then
		echo "WARNING: Could not find tag $tag. Continuing..."
		sleep 2
	else
		echo "Checking out tag $tag..."
		git checkout $tag -- wifisetup/
	fi
fi

cp -r wifisetup build/mycroft/client/

if [ "$1" = "release" ]; then
	git checkout HEAD -- wifisetup/
fi

cd build

cat ../requirements.txt >> requirements.txt
cat ../MANIFEST.in >> mycroft-base-MANIFEST.in

VIRTUALENV_ROOT=${VIRTUALENV_ROOT:-"$HOME/.virtualenvs/mycroft-wifi-setup"}

# create virtualenv, consistent with virtualenv-wrapper conventions
if [ ! -d "${VIRTUALENV_ROOT}" ]; then
   mkdir -p $(dirname "${VIRTUALENV_ROOT}")
  virtualenv -p python2.7 "${VIRTUALENV_ROOT}"
fi

source $VIRTUALENV_ROOT/bin/activate
pip2 install pyinstaller
pip2 install -r requirements.txt

data_args=$(sed '/^ *#/ d' mycroft-base-MANIFEST.in | sed -e 's/^\(recursive\-\)\?include \([^ \n]\+\).*$/--add-data="\2:\2"/gm' | sed -e 's/"\([^*]\+\)\(\*[^:]*\):\1\2"/"\1\2:\1"/gm' | tr '\n' ' ')
eval extra_data="${VIRTUALENV_ROOT}/lib/python2.7/site-packages/pyric/nlhelp/*.help"
for i in $extra_data; do
	data_args="$data_args --add-data=\"$i:pyric/nlhelp/\""
done

eval pyinstaller -y -n mycroft-wifi-setup-client mycroft/client/wifisetup/main.py $data_args --add-data="$extra_data:pyric/nlhelp/" -F

mv dist/mycroft-wifi-setup-client ../dist
echo "Wrote output executable to dist/mycroft-wifi-setup-client"
echo ${version} > version
cd ..
