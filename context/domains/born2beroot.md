# Domain Profile: Born2beRoot (42 school)

## 우선 참조 URL (fetch MCP 힌트)

- Debian 공식: https://www.debian.org/releases/stable/
- Debian installation guide: https://www.debian.org/releases/stable/amd64/
- MySQL 8.0 reference manual: https://dev.mysql.com/doc/refman/8.0/en/
- MySQL InnoDB: https://dev.mysql.com/doc/refman/8.0/en/innodb-storage-engine.html
- PHP manual: https://www.php.net/manual/en/
- PHP-FPM config: https://www.php.net/manual/en/install.fpm.configuration.php
- lighttpd wiki: https://redmine.lighttpd.net/projects/lighttpd/wiki
- Netdata docs: https://learn.netdata.cloud/docs/

## 확립된 Axioms (재증명 불필요)

- **RAM floor**: ~2.2GB raw, ~4.4GB with 2x safety (OS 1GB + MySQL 860MB + PHP 640MB + Netdata 200MB)
- **HDD floor**: ~9.5GB raw, ~19GB with 2x safety
- **MySQL innodb_buffer_pool_size default**: 134217728 bytes (128 MiB)
- **PHP memory_limit default**: 128M
- **PHP-FPM pm.max_children default**: 5
- **Netdata RAM default**: 100~200MB; disk ~3GB (3 tiers)

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
