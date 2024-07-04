#!/bin/bash

set -ex

IFS='+.' read -r major minor patch build_number <<< "$(yq -r .version pubspec.yaml)"
new_patch=$((patch + 1))
new_build_number=$((build_number + 1))
changelog_number=$((new_build_number * 10 + 3))
new_flutter_version="$major.$minor.$new_patch+$new_build_number"
new_version="$major.$minor.$new_patch"

nvim "fastlane/metadata/android/en-US/changelogs/$changelog_number.txt"
changelog=$(cat "fastlane/metadata/android/en-US/changelogs/$changelog_number.txt")
echo "$changelog" > $HOME/fitbook/fastlane/metadata/android/en-US/changelogs/$changelog_number.txt 
echo "$changelog" > fastlane/metadata/en-AU/release_notes.txt
echo "$changelog" > fastlane/metadata/en-US/release_notes.txt

flutter test
dart analyze lib
dart format --set-exit-if-changed lib
./migrate.sh
./screenshots.sh "phoneScreenshots"
./screenshots.sh "sevenInchScreenshots"
./screenshots.sh "tenInchScreenshots"

yq -yi ".version |= \"$new_flutter_version\"" pubspec.yaml
git add pubspec.yaml
git add fastlane/metadata
last_commit=$(git log -1 --pretty=%B | head -n 1)
git commit -m "$new_version 🚀

$changelog"

flutter build apk --split-per-abi
flutter build apk
flutter build appbundle
mkdir -p build/native_assets/linux
flutter build linux

apk=$PWD/build/app/outputs/flutter-apk
(cd $apk/pipeline/linux/x64/release/bundle && zip -r fitbook-linux.zip .)
mv $apk/app-release.apk $apk/fitbook.apk

git push

gh release create "$new_version" --notes "$changelog"  \
  $apk/app-*-release.apk \
  $apk/pipeline/linux/x64/release/bundle/fitbook-linux.zip \
  $apk/fitbook.apk
git pull

bundle exec fastlane supply --aab build/app/outputs/bundle/release/app-release.aab
echo q | flutter run --release || true

set +x
ssh macbook "
  set -e
  source .zprofile 
  cd fitbook 
  git pull 
  security unlock-keychain -p $(pass macbook)
  ./macos.sh || true
  ./ios.sh
"
