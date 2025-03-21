To stage-in the data please follow the instructions below:
- Create an account in https://dataspace.copernicus.eu
- Edit the [usersetting.json](./usersettings.json) with your credentials:
```
{
    "Plugins": {
        "Terradue": {
            "Suppliers": {
                "CDS1": {
                    "Type": "Terradue.Stars.Data.Suppliers.DataHubSourceSupplier",
                    "ServiceUrl": "https://catalogue.dataspace.copernicus.eu/odata/v1",
                    "Priority": 1
                }
            }
        }
    },
    "Credentials": {
        "CDS1": {
            "AuthType": "basic",
            "UriPrefix": "https://identity.dataspace.copernicus.eu",
            "Username": "your registered email",
            "Password": "your password"
        }
    }
} 
```

- Change the product reference in [stage-in.sh](./stage-in.sh) with your desired Sentinel-2 L1C.
- Make the bash script executable:
```
chmod +x stage-in.sh
```
- Run it
```
./stage-in.sh
```