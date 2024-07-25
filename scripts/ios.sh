#!/bin/sh

set -ex

source "$HOME/.zprofile"
cd fitbook
git pull
security unlock-keychain -p ''

flutter build ipa
fastlane deliver --silent --ipa build/ios/ipa/fit_book.ipa
