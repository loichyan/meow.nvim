--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local log = require("spark.log")
local uv = vim.loop
local function new_pipe(cb)
    local pipe, err = uv.new_pipe()
    if pipe == nil then
        log.error(err)
        return
    end
    uv.read_start(
        pipe,
        function(err, ok)
            if err ~= nil then
                log.error(err)
            else
                cb(ok)
            end
        end
    )
    return pipe
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
            local ____uv_spawn_5 = uv.spawn
            local ____table_remove_result_4 = table.remove(gOpts.cmd, 1)
            local ____gOpts_cmd_2 = gOpts.cmd
            local ____gOpts_cwd_3 = gOpts.cwd
            local ____temp_0
            if not opts.onstdout then
                ____temp_0 = nil
            else
                ____temp_0 = new_pipe(opts.onstdout)
            end
            local ____temp_1
            if not opts.onstderr then
                ____temp_1 = nil
            else
                ____temp_1 = new_pipe(opts.onstderr)
            end
            local ok, err = ____uv_spawn_5(
                ____table_remove_result_4,
                {args = ____gOpts_cmd_2, cwd = ____gOpts_cwd_3, stdio = {nil, ____temp_0, ____temp_1}},
                function(____, code, signal)
                    self.__exited = true
                    if opts.onexit ~= nil then
                        opts.onexit(code, signal)
                    end
                end
            )
            if ok == nil then
                log.error(err)
                self.__exited = true
            end
            return self
        end,
        wait = function(self, timeout)
            if timeout == nil then
                timeout = 5000
            end
            vim.wait(
                timeout,
                function()
                    return self.__exited
                end,
                10
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
                    stdout = stdout .. data
                end,
                onstderr = function(data)
                    stderr = stderr .. data
                end
            })
            self:wait(timeout)
            if code == nil or signal == nil then
                return
            end
            return code, signal, stdout, stderr
        end
    }
end}
return ____exports
