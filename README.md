# Alma Barcode Lookup Addon

## Versions
**1.0.6 -** Carleton Fork

**1.0 -** Initial release

## Summary
An Alma Barcode Lookup Addon that uses a barcode to perform an Alma API item lookup and imports the data returned into Ares, Aeon, and ILLiad.

This version is a fork by Carleton University Library. 

Changes in the fork:
* PageCount (Pages), if not found in the item data, is pulled from the Bib's 300 MARC field.
* The publication date is imported. 
* The shelf location is imported.
* The author dates (birth, death) are added if available. 
* The shelf location can be updated using a second button.
* The editor is added from the Bib's 700 MARC field. 


## Settings

> **Alma API URL:** The URL to the Alma API.
>
> **Alma API Key:** API key used for interacting with the Alma API.
>
> **Allow Overwrite with Blank Value:** If turned on, empty values from the API response will overwrite any existing data. *Note:* Non-empty responses will always overwrite existing data.
>
>**Fields to Import:** This is a comma separated lists of the fields to import from the API response into the current product. The name of each field corresponds to the `MappingName` located in the `DataMapping.lua` file.
>The default fields to import are *CallNumber, ISXN, Title, Author, Edition, Place, Pages, and Publisher*. See the *Data Mappings*  or *FAQ* section of the documentation for more details.
>
>**Field to Perform Lookup With:** This is the field in which the barcode is read from. You may specify a custom field or leave it as `{Default}` which will use the field outlined in `DataMapping.lua`. The first value is the table in the database and the second value is the column.
>*Examples: {Default} (uses the field outlined in the DataMapping), Item.ItemBarcode, Transaction.ItemInfo1, or Transaction.Location*

## Buttons
The buttons for the Alma Barcode Lookup Addon are located in the *"Barcode Lookup"* ribbon in the top left of the requests.

>**Import By Barcode:** Currently, the only button in the Alma Barcode Lookup Addon. When clicked, it will use the provided barcode to make an Item Alma API call using the item's barcode.

## FAQ

### How to change the field that the barcode is read from?
The setting that determines the field that the barcode is read from is located in the addon's settings as `"Field to Perform Lookup With"`. It takes in the word `{Default}` or the table name and the column name separated by a `'.'`.

By default it is `{Default}` which tells the addon to get the field from the `DataMapping.lua` file.

### How to change the mappings of an API Lookup Response to Aeon, Ares, or ILLiad's field?
To modify the mappings in this addon, you must edit the `DataMapping.lua` file. Each mapping is an entry on the `DataMapping.FieldMapping[Product Name]` table.

*Example data mapping table:*
```lua
DataMapping.FieldMapping["Ares"] = {};
table.insert(DataMapping.FieldMapping["Ares"], {
    MappingName = "CallNumber",
    ImportField = "Item.Callnumber",
    ObjectType = "item",
    ObjectMapping = "call_number"
});
```

To modify the Aeon, Ares, or ILLiad field the API response item will go into, change the `ImportField` value to desired field. The ImportField formula is `"{Table Name}.{Column Name}"`.

To modify the API response item to go into a particular Aeon, Ares, or ILLiad field, change the `ObjectMapping` value to the desired API XML node name.

### How to change a mapping's name?
The mapping names can be modified to fit the desired use case. Just change the `MappingName` value to the desired name and be sure to include the new `MappingName` value in the `"Fields to Import"` setting, so the addon knows to import that particular mapping.

### How to change Default Barcode Field?
The default barcode field is defined in the `DataMapping.BarcodeFieldMapping[{Product}]` table within the `DataMapping.lua` file. To change the mapping, modify the respective variable to the `"{Table}.{Column}"` of the new field to be mapped to.
