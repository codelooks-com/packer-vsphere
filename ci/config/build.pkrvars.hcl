/*
    CI config — build account.
    build_password, build_password_encrypted and build_key come from PKR_VAR_*
    env (1Password) — do NOT add them here (var-file would override env).
    The username below is the single exception: build.sh greps this file for
    it with an UNANCHORED pattern, so the literal variable name must not
    appear anywhere but the assignment line (a comment mention makes the
    extracted value multi-line and fails validation). It must match
    BUILD_USERNAME in 1Password.
*/

build_username = "packer"
