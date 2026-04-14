# Domain Profile: Born2beRoot (42 school)

## 우선 참조 URL (fetch MCP 힌트)

> 본 파일의 "버전 모호 명시 금지"(아래 §금지 사항) 원칙에 따라 `releases/stable/` 같은 moving target 금지. 모든 URL은 version-pinned deep-link.

- Debian 12 공식: https://www.debian.org/releases/bookworm/
- Debian 12 installation guide: https://www.debian.org/releases/bookworm/amd64/
- MySQL 8.0 reference manual: https://dev.mysql.com/doc/refman/8.0/en/
- MySQL 8.0 InnoDB storage engine: https://dev.mysql.com/doc/refman/8.0/en/innodb-storage-engine.html
- MySQL 8.0 InnoDB parameters: https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html
- MySQL 8.0 InnoDB buffer pool resize: https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-resize.html
- PHP manual (ini core directives): https://www.php.net/manual/en/ini.core.php
- PHP-FPM config: https://www.php.net/manual/en/install.fpm.configuration.php
- lighttpd 1.4 config docs: https://redmine.lighttpd.net/projects/lighttpd/wiki/TutorialConfiguration
- Netdata docs: https://learn.netdata.cloud/docs/

## 확립된 Axioms (재증명 불필요)

> 수치 drift 시 즉시 fact-check 후 업데이트. 각 axiom 은 §우선 참조 URL 중 하나로 verifiable.

- **RAM floor**: ~2.7GB raw (OS 1GB + MySQL 0.86GB + PHP 0.64GB + Netdata 0.2GB), ~5.4GB with 2x safety
- **HDD floor**: ~9.5GB raw, ~19GB with 2x safety
- **MySQL innodb_buffer_pool_size default**: 134217728 bytes (128 MiB) — source: `innodb-buffer-pool-resize.html`
- **PHP memory_limit default**: 128M — source: `ini.core.php`
- **PHP-FPM pm.max_children**: 5 (Debian 12 `/etc/php/8.2/fpm/pool.d/www.conf` 예시값; PHP-FPM 자체 default 없음 — mandatory)
- **Netdata RAM default**: 100~200MB; disk ~3GB (3 tiers, 각 1GiB)

## 학습자 프로파일

- 42 school 학생, C/시스템 프로그래밍 경험 있음
- VR 엔지니어링 배경
- 한국어 사용
- "baby explanations" 원치 않음, 기술 용어 직접 사용 OK

## 금지 사항

- Sci-Hub fallback 사용 금지 (paper-search-mcp 시 `SCIHUB_ENABLED=false`)
- Ghost URL 생성 금지 (fetch 결과 URL만 인용)
- 버전 모호 명시 금지 (예: "MySQL docs" 대신 "MySQL 8.0 Reference Manual")

## 버전 고정

- Debian: 12 (Bookworm)
- MySQL: 8.0
- PHP: 8.2 (Debian 12 기본)
- Netdata: v1.44+
