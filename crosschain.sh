#!/usr/bin/env bash

set -e -o pipefail

cd root-chain
ruby prepare.rb
cd ..

./env.sh bash subchain.sh deploy

cd root-chain
ruby deposit.rb
ruby monitor.rb
cd ..

./env.sh bash subchain.sh issue

./env.sh bash subchain.sh burn

cd root-chain
ruby exit.rb
cd ..
