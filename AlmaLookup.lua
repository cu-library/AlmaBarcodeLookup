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

local function process300APages(threehundredsuba)
    local pages = "";
    -- If there are volumes, don't guess the number of pages
    if (threehundredsuba:find("v%.") == nil and threehundredsuba:find("volume") == nil) then
        -- If the pages contain an "added pages" section...
        if threehundredsuba:find("^.-%[%d-%] p") ~= nil then
            pages = threehundredsuba:match("^.-(%d-) ?pages, %[.*$");
            if pages == nil then
                pages = threehundredsuba:match("^.-(%d-) ?p?%.?, %[.*$");
            end
            if pages == nil then
                pages = threehundredsuba:match("^.-(%d-), %[.*$");
            end
        else
            pages = threehundredsuba:match("^.-([%d]-) ?p%.?.*$");
            if pages == nil then
                pages = threehundredsuba:match("^.-([%d]-) ?pages.*$");
            end
        end
        if pages == nil then
            pages = threehundredsuba;
        end
    end
    return pages;
end

local function DoLookup( itemBarcode )
    local itemResponse = AlmaApi.RetrieveItemByBarcode(itemBarcode);
    
    if (itemResponse == nil) then
        log:Error("Error performing lookup");
        return nil;
    end

    local mmsID = itemResponse:GetElementsByTagName("mms_id"):Item(0);
    local mmsIDToImport = "";

    if(mmsID ~= nil) then
        mmsIDToImport = mmsID.InnerText;
    end

    if (mmsIDToImport == nil or mmsIDToImport == "") then
        log:Error("Error performing mmsID lookup");
        return nil;
    end

    local bibResponse = AlmaApi.RetrieveBibs(mmsIDToImport);
    if (bibResponse == nil) then
        log:Error("Error performing MMSID (bib) lookup");
        return nil;
    end

    local lookupResults = PrepareLookupResults(itemResponse, bibResponse);
    return lookupResults;
end

function PrepareLookupResults(itemResponse, bibResponse)
    local lookupResults = {};

    for _, fieldMapping in ipairs(DataMapping.FieldMapping[product]) do
        for _, fieldToImport in ipairs(fieldsToImport) do
            if(string.lower(Utility.Trim(fieldToImport)) == string.lower(fieldMapping.MappingName)) then
                local destination = LookupUtility.GetValueDestination(fieldMapping, requestType);
                log:DebugFormat("Destination = {0}.{1}", destination[1], destination[2]);
                local importItem = itemResponse:GetElementsByTagName(fieldMapping.ObjectMapping):Item(0);
                local toImport = "";
                
                -- If we selected a tag, take its InnerText
                if(importItem ~= nil) then
                    toImport = importItem.InnerText;
                end
                
                -- Fix the pages
                if (destination[1] == "Item" and destination[2] == "PagesEntireWork" and toImport == "") then
                    local threehundredsuba = bibResponse:SelectSingleNode("//bib[1]/record/datafield[@tag='300']/subfield[@code='a']");
                    -- If we selected a tag, take its InnerText
                    if(threehundredsuba ~= nil) then
                        toImport = process300APages(threehundredsuba.InnerText);
                    end
                end

                -- Fix the imported year
                if (destination[1] == "Item" and destination[2] == "JournalYear") then
                    toImport = toImport:gsub("^[c,%[]", "");
                    toImport = toImport:gsub("%.$", "");
                    toImport = toImport:gsub("%]$", "");
                end

                -- Add more information to the shelf location
                if (destination[1] == "Item" and destination[2] == "ShelfLocation") then
                    local location = itemResponse:GetElementsByTagName("location"):Item(0);
                    if(location ~= nil) then
                        toImport = location:GetAttribute("desc");
                    end
                    toImport = toImport .. " ";
                    local status = itemResponse:GetElementsByTagName("base_status"):Item(0);
                    if(status ~= nil) then
                        toImport = toImport .. status:GetAttribute("desc");
                    end
                end

                -- Fix author
                if (destination[1] == "Item" and destination[2] == "Author" and toImport ~= "") then
                    toImport = toImport:gsub("%,$", "");
                    toImport = toImport:gsub("%.$", "");
                    local onehundredsubd = bibResponse:SelectSingleNode("//bib[1]/record/datafield[@tag='100']/subfield[@code='d']");
                    -- If we selected a tag, take its InnerText
                    if(onehundredsubd ~= nil) then
                        toImport = toImport .. " (" .. onehundredsubd.InnerText:gsub("%.$", "") .. ")";
                    end
                end

                -- Fix the title
                if (destination[1] == "Item" and destination[2] == "Title" and toImport ~= "") then
                    toImport = toImport:gsub(" *%/ *$", "");
                    toImport = toImport:gsub("&amp;", "&");
                    toImport = toImport:gsub(" %.$", ".");
                    toImport = toImport:gsub("not%-for%- profit", "not-for-profit");
                    toImport = toImport:gsub("not%- for%-profit", "not-for-profit");
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

-- Exports
AlmaLookup.DoLookup = DoLookup;
AlmaLookup.InitializeVariables = InitializeVariables;