export interface SpawnOpts {
    onexit?: Lua.MkFn<(code: number, signal: number) => void>;
    onstdout?: Lua.MkFn<(data: string) => void>;
    onstderr?: Lua.MkFn<(data: string) => void>;
}
export interface JobOpts {
    cmd: string[];
    cwd?: string;
}
export interface Job {
    readonly __opts: JobOpts;
    __exited: boolean;
    spawn(this: Job, opts?: SpawnOpts): Job;
    wait(this: Job, timeout?: number): ReturnType<typeof vim.wait>;
    run(this: Job, timeout?: number): Lua.MultiReturn<[number, number, string, string] | [undefined, undefined, undefined, undefined]>;
}
interface JobConstructor {
    new: Lua.MkFn<(opts: JobOpts) => Job>;
}
export declare const Job: JobConstructor;
export {};
