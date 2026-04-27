/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_GC_API_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
