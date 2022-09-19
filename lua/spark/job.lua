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
____exports.Job = {new = function(opts)
    return {
        __opts = opts,
        __exited = false,
        spawn = function(self, opts)
            if opts == nil then
                opts = {}
            end
            local gOpts = self.__opts
            log.debug(
                "run '%s'",
                table.concat(gOpts.cmd, " ")
            )
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
            local hd
            hd = uv.spawn(
                table.remove(gOpts.cmd, 1),
                {args = gOpts.cmd, cwd = gOpts.cwd, stdio = {nil, stdout, stderr}},
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
            local wait_ok, wait_code = self:wait(timeout)
            if not wait_ok then
                if wait_code == -1 then
                    log.error("waiting is timeout")
                else
                    log.error("waiting is interrupted")
                end
            end
            if code == nil or signal == nil then
                return
            end
            return code, signal, stdout, stderr
        end
    }
end}
return ____exports
