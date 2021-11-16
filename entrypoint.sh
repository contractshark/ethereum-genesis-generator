#!/bin/bash -e
CL_ETH1_BLOCK="${CL_ETH1_BLOCK:-0x0000000000000000000000000000000000000000000000000000000000000000}"
CL_TIMESTAMP_DELAY_SECONDS="${CL_TIMESTAMP_DELAY_SECONDS:-300}"
NOW=$(date +%s)
CL_TIMESTAMP=$((NOW + CL_TIMESTAMP_DELAY_SECONDS))

gen_el_config(){
    set -x
    if ! [ -f "/data/el/geth.json" ]; then
        mkdir -p /data/el
        python3 /apps/el-gen/genesis_geth.py /config/el/genesis-config.yaml      > /data/el/geth.json
        python3 /apps/el-gen/genesis_chainspec.py /config/el/genesis-config.yaml > /data/el/chainspec.json
    else
        echo "el genesis already exists. skipping generation..."
    fi
}

gen_cl_config(){
    set -x
    # Consensus layer: Check if genesis already exists
    if ! [ -f "/data/cl/genesis.ssz" ]; then
        mkdir -p /data/cl
        # Replace MIN_GENESIS_TIME on config
        cp /config/cl/config.yaml /data/cl/config.yaml
        sed -i "s/^MIN_GENESIS_TIME:.*/MIN_GENESIS_TIME: ${TIMESTAMP}/" /data/cl/config.yaml
        # Create deposit_contract.txt and deploy_block.txt
        grep DEPOSIT_CONTRACT_ADDRESS /data/cl/config.yaml | cut -d " " -f2 > /data/cl/deposit_contract.txt
        echo "0" > /data/cl/deploy_block.txt
        # Generate genesis
        /usr/local/bin/eth2-testnet-genesis phase0 \
        --config /data/cl/config.yaml \
        --eth1-block "${CL_ETH1_BLOCK}" \
        --mnemonics /config/cl/mnemonics.yaml \
        --timestamp "${CL_TIMESTAMP}" \
        --tranches-dir /data/cl/tranches \
        --state-output /data/cl/genesis.ssz
    else
        echo "cl genesis already exists. skipping generation..."
    fi
}

gen_all_config(){
    gen_el_config
    gen_cl_config
}

case $1 in
  el)
    gen_el_config
    ;;
  cl)
    gen_cl_config
    ;;
  all)
    gen_all_config
    ;;
  *)
    set +x
    echo "Usage: `basename $0` [all|cl|el]"
    exit 1
    ;;
esac

# Start webserver
cd /data && exec python -m SimpleHTTPServer 8000
