/// <reference types="@typescript-to-lua/language-extensions" />
import { Spec } from "./shared";
export declare function new_spec(this: void, spec: DeepParitial<Spec>): Spec;
export declare function validate(this: void, orig: DeepParitial<Spec>): LuaMultiReturn<[Spec, undefined] | [undefined, string]>;
