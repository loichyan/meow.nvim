import { Config, Spec } from "./spark/shared";
export declare function setup(this: void, config?: DeepParitial<Config>): void;
export declare function plugins(this: void): Spec[];
export declare function install(this: void): void;
export declare function load(this: void): void;
export declare function clean(this: void): void;
