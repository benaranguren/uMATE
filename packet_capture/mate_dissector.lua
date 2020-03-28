
DissectorTable.new("matenet")
mate_proto = Proto("matenet", "Outback MATE serial protocol")

local COMMANDS = {
    [0] = "Inc/Dis",  -- Increment or Disable (depending on the register)
    [1] = "Dec/En",   -- Decrement or Enable
    [2] = "Read",
    [3] = "Write",
    [4] = "Status",
    [22] = "Get Logpage"
}

local CMD_READ = 2
local CMD_WRITE = 3
local CMD_STATUS = 4

local DEVICE_TYPES = {
    [1] = "Hub",
    [2] = "(FX) FX Inverter",
    [3] = "(CC) MX Charge Controller",
    [4] = "(DC) FLEXnet DC"
}
local DEVICE_TYPES_SHORT = {
    [1] = "HUB",
    [2] = "FX",
    [3] = "CC",
    [4] = "DC"
}

local DTYPE_HUB = 1
local DTYPE_FX = 2
local DTYPE_CC = 3
local DTYPE_DC = 4

local REG_DEVICE_TYPE = 0x0000

local MX_STATUS = {
    [0] = "Sleeping",
    [1] = "Floating",
    [2] = "Bulk",
    [3] = "Absorb",
    [4] = "Equalize",
}

local MX_AUX_MODE = {
    [0] = "Disabled",
    [1] = "Diversion",
    [2] = "Remote",
    [3] = "Manual",
    [4] = "Fan",
    [5] = "PV Trigger",
    [6] = "Float",
    [7] = "ERROR Output",
    [8] = "Night Light",
    [9] = "PWM Diversion",
    [10] = "Low Battery"
}

local QUERY_REGISTERS = {
    -- MX/FX (Not DC)
    [0x0000] = "Device Type",
    -- [0x0001] = "FW Revision",

    -- FX
    -- [0x0039] = "Errors",
    -- [0x0059] = "Warnings",
    -- [0x003D] = "Inverter Control",
    -- [0x003A] = "AC In Control",
    -- [0x003C] = "Charge Control",
    -- [0x005A] = "AUX Mode",
    -- [0x0038] = "Equalize Control",
    -- [0x0084] = "Disconn Status",
    -- [0x008F] = "Sell Status",
    -- [0x0032] = "Battery Temperature",
    -- [0x0033] = "Air Temperature",
    -- [0x0034] = "MOSFET Temperature",
    -- [0x0035] = "Capacitor Temperature",
    -- [0x002D] = "Output Voltage",
    -- [0x002C] = "Input Voltage",
    -- [0x006D] = "Inverter Current",
    -- [0x006A] = "Charger Current",
    -- [0x006C] = "Input Current",
    -- [0x006B] = "Sell Current",
    -- [0x0019] = "Battery Actual",
    -- [0x0016] = "Battery Temperature Compensated",
    -- [0x000B] = "Absorb Setpoint",
    -- [0x0070] = "Absorb Time Remaining",
    -- [0x000A] = "Float Setpoint",
    -- [0x006E] = "Float Time Remaining",
    -- [0x000D] = "Refloat Setpoint",
    -- [0x000C] = "Equalize Setpoint",
    -- [0x0071] = "Equalize Time Remaining",

    -- MX
    -- [0x0008] = "Battery Voltage",
    -- [0x000F] = "Max Battery",
    -- [0x0010] = "V OC",
    -- [0x0012] = "Max V OC",
    -- [0x0013] = "Total kWh DC",
    -- [0x0014] = "Total kAh",
    -- [0x0015] = "Max Wattage",
    -- [0x016A] = "Charger Watts",
    -- [0x01EA] = "Charger kWh",
    -- [0x01C7] = "Charger Amps DC",
    -- [0x01C6] = "Panel Voltage",
    -- [0x01C8] = "Status",
    -- [0x01C9] = "Aux Relay Mode",
    -- [0x0170] = "Setpoint Absorb",
    -- [0x0172] = "Setpont Float",
}

-- Remember which device types are attached to each port
-- (Only available if you capture this data on startup!)
local device_table = {}
local device_table_available = false


local pf = {
    --bus = ProtoField.uint8("matenet.bus", "Bus", base.HEX),
    port                    = ProtoField.uint8("matenet.port", "Port", base.DEC),
    cmd                     = ProtoField.uint8("matenet.cmd", "Command", base.HEX, COMMANDS),
    device_type             = ProtoField.uint8("matenet.device_type", "Device Type", base.HEX, DEVICE_TYPES_SHORT),
    data                    = ProtoField.bytes("matenet.data", "Data", base.NONE),
    addr                    = ProtoField.uint16("matenet.addr", "Address", base.HEX),
    query_addr              = ProtoField.uint16("matenet.queryaddr", "Address", base.HEX, QUERY_REGISTERS),
    value                   = ProtoField.uint16("matenet.value", "Value", base.HEX),
    check                   = ProtoField.uint16("matenet.checksum", "Checksum", base.HEX),

    mxstatus_ah             = ProtoField.float("matenet.mxstatus.amp_hours",    "Amp Hours",        {"Ah"}),
    mxstatus_pv_current     = ProtoField.int8("matenet.mxstatus.pv_current",   "PV Current",        base.UNIT_STRING, {"A"}),
    mxstatus_bat_current    = ProtoField.int8("matenet.mxstatus.bat_current",  "Battery Current",   base.UNIT_STRING, {"A"}),
    mxstatus_kwh            = ProtoField.float("matenet.mxstatus.kwh",          "Kilowatt Hours",   {"kWh"}),
    mxstatus_bat_voltage    = ProtoField.float("matenet.mxstatus.bat_voltage",  "Battery Voltage",  {"V"}),
    mxstatus_pv_voltage     = ProtoField.float("matenet.mxstatus.pv_voltage",   "PV Voltage",       {"V"}),
    mxstatus_aux_state      = ProtoField.uint8("matenet.mxstatus.aux_state",    "Aux State",        base.DEC, NULL, 0x40),
    mxstatus_aux_mode       = ProtoField.uint8("matenet.mxstatus.aux_mode",     "Aux Mode",         base.DEC, MX_AUX_MODE, 0x3F),
    mxstatus_status         = ProtoField.uint8("matenet.mxstatus.status",       "Status",           base.DEC, MX_STATUS),
    mxstatus_errors         = ProtoField.uint8("matenet.mxstatus.errors",       "Errors",           base.DEC),
    mxstatus_errors_1       = ProtoField.uint8("matenet.mxstatus.errors.e3",    "High VOC",         base.DEC, NULL, 128),
    mxstatus_errors_2       = ProtoField.uint8("matenet.mxstatus.errors.e2",    "Too Hot",          base.DEC, NULL, 64),
    mxstatus_errors_3       = ProtoField.uint8("matenet.mxstatus.errors.e1",    "Shorted Battery Sensor", base.DEC, NULL, 32),
}
mate_proto.fields = pf

function fmt_cmd(cmd, prior_cmd)
    if prior_cmd then
    end
    return COMMANDS[cmd:uint()]
end



function fmt_addr(cmd)
    -- INC/DEC/READ/WRITE : Return readable register name
    if cmd:uint() <= 3 then
        name = QUERY_REGISTERS[addr:uint()]
        if name then
            return name
        end
    end

    return addr
end

function fmt_mx_status()
    -- TODO: Friendly MX status string
    return "MX STATUS"
end

function fmt_response(port, cmd, addr, resp_data)
    cmd = cmd:uint()
    addr = addr:uint()

    -- QUERY DEVICE TYPE
    if (cmd == CMD_READ) and (addr == REG_DEVICE_TYPE) then
        -- Remember the device attached to this port
        local dtype = resp_data:uint()
        device_table[port:uint()] = dtype
        device_table_available = true

        return DEVICE_TYPES[dtype]
    end
    
    if device_table_available then
        local dtype = device_table[port:uint()]
        if (cmd == CMD_STATUS) then
            -- Format status packets
            if dtype == DTYPE_CC then
                --return fmt_mx_status(resp_data)
            end
        end
    end

    return resp_data
end

function fmt_dest(port)
    local dtype = device_table[port:uint()]
    if dtype then
        return "Port " .. port .. " (" .. DEVICE_TYPES_SHORT[dtype] .. ")"
    else
        return "Port " .. port
    end
end

function parse_mx_status(addr, data, tree)
    -- Byte 0:
    --   [7]: 1 (If this is 0, some of the AH printout disappears!)
    --   [6..4]: AH (upper byte)
    --   [3..0]: ?? Modifies out current & kW when 0x0F (but not any other value, and only on CC totals screen!)
    local raw_ah = bit.bor(
        bit.rshift(bit.band(data(0,1):uint(), 0x70), 4),
        data(4,1):uint()
    )

    local raw_kwh = bit.bor(
        bit.lshift(data(3,1):uint(), 8),
        data(8,1):uint()
    ) / 10.0

    tree:add(pf.mxstatus_pv_current,  data(1,1), (data(1,1):int()+128))
    tree:add(pf.mxstatus_bat_current, data(2,1), (data(2,1):int()+128))

    tree:add(pf.mxstatus_ah, data(4,1), raw_ah)  -- composite value
    tree:add(pf.mxstatus_kwh, data(8,1), raw_kwh) -- composite value

    tree:add(pf.mxstatus_status, data(6,1))
    


    local error_node = tree:add(pf.mxstatus_errors, data(7,1))
    error_node:add(pf.mxstatus_errors_1, data(7,1))
    error_node:add(pf.mxstatus_errors_2, data(7,1))
    error_node:add(pf.mxstatus_errors_3, data(7,1))

    tree:add(data(0,1), "Unknown Field:", bit.band(data(0,1):uint(), 0x0F))

    -- always seems to be 0x3F
    tree:add(data(5,1), "Unknown Field:", data(5,1):uint()) 

    -- TODO: Aux Mode
    --tree:add(pf.mxstatus_aux_state, data(0,1))
    --tree:add(pf.mxstatus_aux_mode, data(0,1))

    tree:add(pf.mxstatus_bat_voltage, data(9,2), (data(9,2):uint()/10.0))
    tree:add(pf.mxstatus_pv_voltage, data(11,2), (data(11,2):uint()/10.0))
end

function parse_fx_status(addr, data, tree)
    tree:add(data(0,1), "FX STATUS")
end

function parse_dc_status(addr, data, tree)
    tree:add(data(0,1), "DC STATUS")
end

--local ef_too_short = ProtoExpert.new("mate.too_short.expert", "MATE packet too short",
--                                    expert.group.MALFORMED, expert.severity.ERROR)

local prior_cmd = nil
local propr_cmd_port = nil
local prior_cmd_addr = nil

function dissect_frame(bus, buffer, pinfo, tree, combine)
    -- MATE TX (Command)
    if bus == 0xA then
        if not combine then
            pinfo.cols.src = "MATE"
            pinfo.cols.dst = "Device"
        end
        
        local subtree = tree:add(mate_proto, buffer(), "Command")
        
        if buffer:len() <= 7 then
            return
        end

        port = buffer(0, 1)
        cmd  = buffer(1, 1)
        addr = buffer(2, 2)
        value = buffer(4, 2)
        check = buffer(6, 2)
        --data = buffer(4, buffer:len()-4)
        subtree:add(pf.port, port)
        subtree:add(pf.cmd,  cmd)
        --subtree:add(pf.data, data)

        --pinfo.cols.info:set("Command")
        info = fmt_cmd(cmd)
        if info then
            pinfo.cols.info:prepend(info .. " ")
        end

        -- INC/DEC/READ/WRITE/STATUS
        if cmd:uint() <= 4 then
            subtree:add(pf.query_addr, addr)
            pinfo.cols.info:append(" ["..fmt_addr(addr).."]")
        else
            subtree:add(pf.addr, addr)
        end

        subtree:add(pf.value, value)
        subtree:add(pf.check, check)

        pinfo.cols.dst = fmt_dest(port)

        prior_cmd = cmd
        prior_cmd_port = port
        prior_cmd_addr = addr
        
        return -1
        
    -- MATE RX (Response)
    elseif bus == 0xB then
        if not combine then
            pinfo.cols.src = "Device"
            pinfo.cols.dst = "MATE"
        end
        
        local subtree = tree:add(mate_proto, buffer(), "Response")

        if buffer:len() <= 3 then
            return
        end
        
        cmd = buffer(0, 1)
        if combine and (prior_cmd:uint() == CMD_STATUS) then
            -- For STATUS responses, this is the type of device that sent the status
            subtree:add(pf.device_type, cmd)
        else
            -- Otherwise it should match the command that this is responding to
            subtree:add(pf.cmd, cmd)
        end
    
        data = buffer(1, buffer:len()-3)
        check = buffer(buffer:len()-2, 2)
        local data_node = subtree:add(pf.data, data)
        subtree:add(pf.check, check)

        if not combine then
            pinfo.cols.info:set("Response")

            info = fmt_cmd(cmd, prior_cmd)
            if info then
                pinfo.cols.info:prepend(info .. " ")
            end
        else
            -- append the response value
            -- INC/DEC/READ/WRITE
            if cmd:uint() <= 3 then
                pinfo.cols.info:append(" : " .. fmt_response(
                    prior_cmd_port, 
                    prior_cmd, 
                    prior_cmd_addr, 
                    data
                ))
            end

            -- We know what type of device is attached to this port,
            -- so do some additional parsing...
            if device_table_available then
                local cmd = prior_cmd:uint()
                local addr = prior_cmd_addr:uint()
                local dtype = device_table[port:uint()]

                -- Parse status packets
                if (cmd == CMD_STATUS) then
                    if dtype == DTYPE_CC then
                        parse_mx_status(addr, data, data_node)
                    elseif dtype == DTYPE_FX then
                        parse_fx_status(addr, data, data_node)
                    elseif dtype == DTYPE_DC then
                        parse_dc_status(addr, data, data_node)
                    end
                end
            end
        end
    end
end

function mate_proto.dissector(buffer, pinfo, tree)
    len = buffer:len()
    if len == 0 then return end

    pinfo.cols.protocol = mate_proto.name

    --local subtree = tree:add(mate_proto, buffer(), "MATE Data")

    -- if len < 5 then
    --     subtree.add_proto_expert_info(ef_too_short)
    --     return
    -- end

    bus = buffer(0, 1):uint()
    --subtree:add(pf.bus, bus)
    buffer = buffer(1, buffer:len()-1)

    -- local data = {}
    -- for i=0,buffer:len() do
    --     data[i] = i
    -- end
    
    -- Combined RX/TX
    if bus == 0x0F then
        len_a = buffer(0, 1):uint()
        len_b = buffer(1, 1):uint()
        
        buf_a = buffer(2, len_a)
        buf_b = buffer(2+len_a, len_b)
        
        r_a = dissect_frame(0xA, buf_a, pinfo, tree, true)
        r_b = dissect_frame(0xB, buf_b, pinfo, tree, true)
        --return r_a + r_b
        
        pinfo.cols.src = "MATE"
        --pinfo.cols.dst = "Device"
        
    else
        return dissect_frame(bus, buffer, pinfo, tree, false)
    end


end

-- This function will be invoked by Wireshark during initialization, such as
-- at program start and loading a new file
function mate_proto.init()
    device_table = {}
    device_table_available = false
end


DissectorTable.get("matenet"):add(147, mate_proto) -- DLT_USER0