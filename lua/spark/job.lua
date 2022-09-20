--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local log = require("spark.log")
local uv = vim.loop
local function new_pipe()
    local pipe, err = uv.new_pipe()
    if pipe == nil then
        log.error(err)
        return
    end
    return pipe
end
local function mk_pipe_reader(cb)
    return function(err, ok)
        if err ~= nil then
            log.error(err)
        elseif ok ~= nil then
            cb(ok)
        end
    end
end
local function cmd2str(cmd)
    return table.concat(cmd, " ")
end
____exports.Job = {new = function(opts)
    return {
        __opts = opts,
        __exited = false,
        spawn = function(self, opts)
            if opts == nil then
                opts = {}
            end
            local gOpts = self.__opts
            local cmd = gOpts.cmd
            local ____temp_0
            if opts.onstdout == nil then
                ____temp_0 = nil
            else
                ____temp_0 = new_pipe()
            end
            local stdout = ____temp_0
            local ____temp_1
            if opts.onstderr == nil then
                ____temp_1 = nil
            else
                ____temp_1 = new_pipe()
            end
            local stderr = ____temp_1
            log.debug(
                "run '%s'",
                cmd2str(cmd)
            )
            local hd
            hd = uv.spawn(
                cmd[1],
                {
                    args = {unpack(cmd, 2)},
                    cwd = gOpts.cwd,
                    stdio = {nil, stdout, stderr}
                },
                function(code, signal)
                    self.__exited = true
                    uv.close(hd)
                    if opts.onexit ~= nil then
                        opts.onexit(code, signal)
                    end
                end
            )
            if stdout ~= nil and opts.onstdout ~= nil then
                uv.read_start(
                    stdout,
                    mk_pipe_reader(opts.onstdout)
                )
            end
            if stderr ~= nil and opts.onstderr ~= nil then
                uv.read_start(
                    stderr,
                    mk_pipe_reader(opts.onstderr)
                )
            end
            return self
        end,
        wait = function(self, timeout)
            if timeout == nil then
                timeout = 5000
            end
            return vim.wait(
                timeout,
                function()
                    return self.__exited
                end,
                200
            )
        end,
        run = function(self, timeout)
            if timeout == nil then
                timeout = 5000
            end
            local stdout = ""
            local stderr = ""
            local code
            local signal
            self:spawn({
                onexit = function(c, s)
                    code = c
                    signal = s
                end,
                onstdout = function(data)
                    stdout = stdout .. data .. "\n"
                end,
                onstderr = function(data)
                    stderr = stderr .. data .. "\n"
                end
            })
            local wait_ok = self:wait(timeout)
            if not wait_ok then
                log.error(
                    "waiting '%s' failed",
                    cmd2str(self.__opts.cmd)
                )
            end
            if code == nil or signal == nil then
                return nil, nil, nil, nil
            elseif code ~= 0 then
                log.error(
                    "run '%s' exited with error '%s'",
                    cmd2str(self.__opts.cmd),
                    stderr
                )
            end
            return code, signal, stdout, stderr
        end
    }
end}
return ____exports
