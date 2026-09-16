import { readFileSync } from 'node:fs';
import YAML from 'yaml';

export function loadOpenApiSpec(): object {
  const path = new URL('../../docs/openapi.yaml', import.meta.url);
  return YAML.parse(readFileSync(path, 'utf8')) as object;
}