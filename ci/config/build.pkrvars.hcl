/*
    CI config — build account.
    build_password, build_password_encrypted and build_key come from PKR_VAR_*
    env (1Password) — do NOT add them here (var-file would override env).
    build_username is the single exception: build.sh's validate_linux_username
    greps it from this file. It must match BUILD_USERNAME in 1Password.
*/

build_username = "packer"
