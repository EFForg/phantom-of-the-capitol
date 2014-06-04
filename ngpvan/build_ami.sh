#!/usr/bin/env bash
debugFlag=""
if [ $1 = "-debug" ]; then 
  echo "Packer debug mode enabled."
  debugFlag="-debug"
fi
packer build $debugFlag -var aws_access_key=AKIAJFWCR7FY4FTKD53A -var aws_secret_key=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 packer.json
