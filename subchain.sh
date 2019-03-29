#!/usr/bin/env bash

set -e -o pipefail

# Test private key & address
PKEY="1234567890123456789012345678901234567890123456789012345678901234"
PADDR="2e988a386a799f506693793c6a5af6b54dfaabfb"

MAIN_CONTRACT_ADDR=
SIDE_CONTRACT_ADDR=

ISSUE_ABI=[{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_proof","type":"bytes"},{"name":"_dataSize","type":"uint256"}],"name":"checkProof","outputs":[{"name":"data","type":"bytes"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"burn","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"acceptOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"issue","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"success","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"newOwner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"remaining","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Issue","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_account","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Burn","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_from","type":"address"},{"indexed":true,"name":"_to","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Transfer","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_owner","type":"address"},{"indexed":true,"name":"_spender","type":"address"},{"indexed":false,"name":"_value","type":"uint256"}],"name":"Approval","type":"event"}]

# Base dir for import contract files
CONTRACT_LIBS_DIR="subchain/CrossChainToken"
CONTRACT="subchain/CrossChainToken/CrossChainToken.sol"

function txtool_run () {
    cd "cita/scripts/txtool/txtool"
    python3 "$@"
    cd ../../../..
}

function python_run () {
    local pycmd="$1;"
    shift 1
    while [ -n "$1" ]; do
        pycmd="${pycmd} $1;"
        shift 1
    done
    python3 -c "${pycmd}"
}

function json_get () {
    #"outfmt = sys.argv[1].strip().split('.')[1:]" \
    local outfmt="$1"
    python_run \
        "import json" \
        "import sys" \
        "from functools import reduce" \
        "instr = sys.stdin.read().strip()" \
        "injson = json.loads(instr)" \
        "outfmt = \"${outfmt}\".strip().split('.')[1:]" \
        "print(reduce(lambda x, y: x[y], outfmt, injson))"
}

function abi_encode () {
    local abi="$1"
    local func="$2"
    local data="$3"
    python_run \
        "from ethereum.abi import ContractTranslator" \
        "import binascii" \
        "ct = ContractTranslator(b'''${abi}''')" \
        "tx = ct.encode('${func}', [${data}])" \
        "print(binascii.hexlify(tx).decode('utf-8'))"
}

function get_addr () {
    txtool_run get_receipt.py --forever true \
        | json_get .contractAddress | cut -c 3-
}

function deploy_contract () {
    local solfile="$1"
    local extra="$2"
        
    local code="$(solc --allow-paths "$(pwd)/${CONTRACT_LIBS_DIR}" \
        --bin "${solfile}" |  grep "${solfile}" -A 2 | tail -1)${extra}"

    echo "${code}"
    txtool_run make_tx.py --privkey "${PKEY}" --code "${code}" --quota 10000000
    txtool_run send_tx.py
    txtool_run get_receipt.py --forever true
}

function send_contract () {
    local addr="$1"
    local abi="$2"
    local func="$3"
    local input="$4"
    local code="$(abi_encode "${abi}" "${func}" "${input}")"
    txtool_run make_tx.py --privkey "${PKEY}" \
        --to "0x${addr}" --code "0x${code}"
    txtool_run send_tx.py
    txtool_run get_receipt.py --forever true
}

function call_contract () {
    local addr="$1"
    local code="$2"
    curl -s -X POST -d "$(printf "${JSONRPC_CALL}" "0x${addr}" "0x${code}")" \
        127.0.0.1:1337 \
        | json_get .result | xargs -I {} echo {}
}

function deploy () {
    echo "Prepare: Deploy sidechain contract"
    deploy_contract "${CONTRACT}"
    SIDE_CONTRACT_ADDR=$(get_addr)
    echo ${SIDE_CONTRACT_ADDR} > 'address'
}

function issue () {
    SIDE_CONTRACT_ADDR=`cat address`

    DEMO_ABI=$(solc --allow-paths "$(pwd)/${CONTRACT_LIBS_DIR}" \
            --combined-json abi ${CONTRACT} \
        | sed "s@${CONTRACT}:@@g" \
        | json_get '.contracts.CrossChainToken.abi')

    send_contract "${SIDE_CONTRACT_ADDR}" "${DEMO_ABI}" "issue" "0x${PADDR}, 4000"
}

function burn () {
    SIDE_CONTRACT_ADDR=`cat address`

    DEMO_ABI=$(solc --allow-paths "$(pwd)/${CONTRACT_LIBS_DIR}" \
            --combined-json abi ${CONTRACT} \
        | sed "s@${CONTRACT}:@@g" \
        | json_get '.contracts.CrossChainToken.abi')

    send_contract "${SIDE_CONTRACT_ADDR}" "${DEMO_ABI}" "burn"
}

case $1 in
    deploy)
        deploy
        ;;
    issue)
        issue
        ;;
    burn)
        burn
        ;;
esac
