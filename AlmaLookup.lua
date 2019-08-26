AlmaLookup = {};

-- Load the .Net types that we will be using.
local types = {};
types["log4net.LogManager"] = luanet.import_type("log4net.LogManager");
types["System.Xml.XmlDocument"] = luanet.import_type("System.Xml.XmlDocument");

local log = types["log4net.LogManager"].GetLogger(rootLogger .. ".AlmaLookup");
local allowOverwriteWithBlankValue = nil;
local fieldsToImport = nil;
local requestType = nil;

local function InitializeVariables(almaApiUrl, almaApiKey, overwriteWithBlankValue, toImport)
    AlmaApi.ApiUrl = almaApiUrl;
    AlmaApi.ApiKey = almaApiKey;
    allowOverwriteWithBlankValue = overwriteWithBlankValue;
    fieldsToImport = toImport;

    if(product == "ILLiad") then
        requestType = GetFieldValue("Transaction","RequestType");
    end
end

local function DoLookup( itemBarcode )
    local succeeded, response = pcall(AlmaApi.RetrieveItemByBarcode, itemBarcode);

    if not succeeded then
        log:Error("Error performing lookup");
        return nil;
    end
    
    local lookupResults = PrepareLookupResults(response);
    
    -- If we find valid pages in the item, exit early. 
    if(lookupResults ~= nil) then
        for _, result in ipairs(lookupResults) do
            if(result.valueDestination[1] == "Item" and result.valueDestination[1] == "PageCount" and result.valueToImport ~= "") then
                return lookupResults;
            end
        end
    end
    
    local mmsID = response:GetElementsByTagName("mms_id"):Item(0);
    local mmsIDToImport = "";

    if(mmsID ~= nil) then
        mmsIDToImport = mmsID.InnerText;
    end

    log:DebugFormat("mmsID: {0}", mmsIDToImport);
    local pages = "";
    
    if(mmsIDToImport ~= nil and mmsIDToImport ~= "") then
        local bibCallSucceeded, bibResponse = pcall(AlmaApi.RetrieveBibs, mmsIDToImport);
        if not bibCallSucceeded then
            log:Error("Error performing MMSID (bib) lookup");
        end
        
        local threehundredsuba = bibResponse:SelectSingleNode("//bib[1]/record/datafield[@tag='300']/subfield[@code='a']");
        local threehundredsubaToImport = "";

        -- If we selected a tag, take its InnerText
        if(threehundredsuba ~= nil) then
           threehundredsubaToImport = threehundredsuba.InnerText;
        end
        
        pages = process300APages(threehundredsubaToImport);
    end;
    
    local pagesValueDestination={};
    pagesValueDestination[1] = "Item";
    pagesValueDestination[2] = "PageCount";
    
    table.insert( lookupResults,{
                  valueDestination = pagesValueDestination;
                  valueToImport = pages;
    });
    
    log:DebugFormat("pages: {0}", pages);
    
    return lookupResults;
   
end

function PrepareLookupResults(response)
    local lookupResults = {};

    for _, fieldMapping in ipairs(DataMapping.FieldMapping[product]) do
        for _, fieldToImport in ipairs(fieldsToImport) do
            if(string.lower(Utility.Trim(fieldToImport)) == string.lower(fieldMapping.MappingName)) then
                local destination = LookupUtility.GetValueDestination(fieldMapping, requestType);
                log:DebugFormat("Destination = {0}.{1}", destination[1], destination[2]);
                local importItem = response:GetElementsByTagName(fieldMapping.ObjectMapping):Item(0);
                local toImport = "";

                -- If we selected a tag, take its InnerText
                if(importItem ~= nil) then
                    toImport = importItem.InnerText;
                end

                log:DebugFormat("To Import = {0}", toImport);
                -- If overwrite with blank value is false and the value to import is nil or empty, break
                if(not allowOverwriteWithBlankValue and (toImport == nil or toImport == "") ) then
                    break;
                end

                table.insert( lookupResults,{
                  valueDestination = destination;
                  valueToImport = toImport;
                });
            end
        end
    end

    return lookupResults;
end

function process300APages(threehundredsuba)
    local pages = ""
    -- If there are volumes, don't guess the number of pages
    if (threehundredsuba:find("v%.") == nil and threehundredsuba:find("volume") == nil) then
        -- If the pages contain an "added pages" section...
        if threehundredsuba:find("^.-%[%d-%] p") ~= nil then
            pages = threehundredsuba:match("^.-(%d-) ?pages, %[.*$")
            if pages == nil then
                pages = threehundredsuba:match("^.-(%d-) ?p?%.?, %[.*$")
            end
            if pages == nil then
                pages = threehundredsuba:match("^.-(%d-), %[.*$")
            end
        else 
            pages = threehundredsuba:match("^.-([%d]-) ?p%.?.*$")
            if pages == nil then
                pages = threehundredsuba:match("^.-([%d]-) ?pages.*$")
            end
        end
        
        if pages == nil then
            pages = threehundredsuba
        end
    end
    
    return pages
end

-- Exports
AlmaLookup.DoLookup = DoLookup;
AlmaLookup.InitializeVariables = InitializeVariables;