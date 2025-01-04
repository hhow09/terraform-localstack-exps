#!/bin/bash
## to package lambda functions
for function in $(ls lambda/)
do 
   pushd "lambda/$function"
   if [ -f "deployment_package.zip" ]; then rm -f deployment_package.zip; fi
   # match python version with aws_lambda_function.runtime in main.tf to avoid bug
   python3.12 -m pip install --target ./packages --requirement ./src/requirements.txt
   pushd packages
   zip -r ../deployment_package.zip .
   popd
   pushd src/
   zip -g ../deployment_package.zip lambda_function.py
   popd
   rm -rf packages/*
   popd
done
