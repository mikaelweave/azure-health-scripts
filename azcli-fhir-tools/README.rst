Microsoft Azure CLI 'test' Extension
==========================================

This package is for the 'test' extension.
i.e. 'az test'

Testing
```
az extension remove --name fhir-tools 
python setup.py bdist_wheel
az extension add --source dist/fhir_tools-*-py3-none-any.whl
```