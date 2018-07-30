function print_indexed_table(table_to_print, indent)
    local indent = indent or 0
    for k, v in ipairs(table_to_print) do
        local formatting = string.rep("  ", indent) .. "[" .. k .. "] = "
        if type(v) == "table" then
            print(formatting)
            print_indexed_table(v, indent+1)
        elseif type(v) == 'boolean' or type(v) == 'function' then
            print(formatting .. tostring(v))      
        else
            print(formatting .. v)
        end
    end
end

function print_table(table_to_print, indent)
    local indent = indent or 0
    for k, v in pairs(table_to_print) do
        
        local formatting
        if type(k) == 'table' then
            formatting = string.rep("  ", indent) .. "[table]" .. ": "
        else
            local key_ = k
            if type(k) == "boolean" then
                key_ = tostring(k)
            end
            formatting = string.rep("  ", indent) .. key_ .. ": "
        end
        
        if string.find(formatting, "__") == 1 then
            -- skip this internal item
        else
               
            if type(v) == "table" then
                print(formatting)
                if indent > 20 then
                    print("tables nested 20 deep?")
                else
                    print_table(v, indent+1)
                end
            elseif type(v) == 'boolean' or type(v) == 'function' or type (v) == 'userdata' then
                print(formatting .. tostring(v))      
            else
                print(formatting .. v)
            end
        end
        
    end
end
