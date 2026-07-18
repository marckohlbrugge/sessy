# sessy-saas

Companion Rails engine for the hosted version of [Sessy](https://github.com/marckohlbrugge/sessy). It is loaded only when bundling with `Gemfile.saas` (`SESSY_MODE=saas` in development) and holds everything specific to the hosted edition, keeping the open-source app free of hosted-only code.

This engine is not meant to be used by third parties — the [O'Saasy license](LICENSE.md) does not permit offering Sessy as a competing hosted service — but it can serve as inspiration for anyone running Sessy on their own infrastructure.
