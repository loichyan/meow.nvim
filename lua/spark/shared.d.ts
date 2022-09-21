export declare type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR";
export declare type SpecState = "NONE" | "MOVE" | "CLONE" | "REMOVE" | "DISABLE" | "LOAD" | "POST_LOAD" | "LOADED";
export interface Spec {
    [1]: string;
    from: string;
    start: boolean;
    disable: boolean;
    priority: number;
    setup?: Lua.MkFn<() => void>;
    after: string[];
    run?: Lua.MkFn<() => void> | string[];
    __state: SpecState;
    __path: string;
}
export declare const DEFAULT_SPEC: Spec;
export interface Config {
    [1]: Lua.MkFn<(use: Lua.MkFn<(spec: Partial<Spec>) => void>) => void>;
    root: string;
    log: {
        level: LogLevel;
    };
    post_load?: Lua.MkFn<(spec: Spec) => void>;
}
export declare const CONFIG: Config;
export declare const PLUGINS: Spec[];
