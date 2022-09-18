import { Spec } from "./shared";
export declare function resolve_after(this: void, specs: Spec[]): Lua.MultiReturn<[Spec[], undefined] | [undefined, string]>;
export declare function resolve(this: void, specs: Spec[]): Lua.MultiReturn<[Spec[], undefined] | [undefined, string]>;
