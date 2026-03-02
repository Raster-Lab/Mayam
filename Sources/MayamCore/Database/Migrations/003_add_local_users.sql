BEGIN;

CREATE TABLE IF NOT EXISTS local_users (
    username       TEXT PRIMARY KEY,
    password_hash  TEXT NOT NULL,
    role           TEXT NOT NULL CHECK (role IN ('administrator','technologist','physician','auditor')),
    email          TEXT,
    display_name   TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ldap_configuration (
    id              INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    enabled         BOOLEAN NOT NULL DEFAULT false,
    host            TEXT NOT NULL DEFAULT '',
    port            INTEGER NOT NULL DEFAULT 389,
    use_tls         BOOLEAN NOT NULL DEFAULT false,
    service_bind_dn TEXT NOT NULL DEFAULT '',
    service_bind_password TEXT NOT NULL DEFAULT '',
    base_dn         TEXT NOT NULL DEFAULT '',
    user_search_filter TEXT NOT NULL DEFAULT '(objectClass=person)',
    username_attribute TEXT NOT NULL DEFAULT 'uid',
    email_attribute TEXT NOT NULL DEFAULT 'mail',
    display_name_attribute TEXT NOT NULL DEFAULT 'cn',
    member_of_attribute TEXT NOT NULL DEFAULT 'memberOf',
    admin_group_dn  TEXT NOT NULL DEFAULT '',
    tech_group_dn   TEXT NOT NULL DEFAULT '',
    physician_group_dn TEXT NOT NULL DEFAULT '',
    auditor_group_dn   TEXT NOT NULL DEFAULT '',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE local_users IS 'Local user accounts used for authentication when LDAP is disabled or unavailable.';
COMMENT ON TABLE ldap_configuration IS 'LDAP/Active Directory integration configuration (single-row table).';

COMMIT;
