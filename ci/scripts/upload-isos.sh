#!/usr/bin/env bash
# Download, checksum-verify, and upload OS install ISOs to the datastore
# locations the Packer builds read from. Idempotent: an ISO already present
# at its datastore path is skipped, so running with "all" is always safe.
# Driven by ci/matrix.json; the iso_url basename must equal the iso_file in
# the line's ci/config var-file (consistency check, fail-fast).
#
# Usage: upload-isos.sh <key|all>
# Requires: govc env (GOVC_URL/USERNAME/PASSWORD/INSECURE), jq, curl.
# ISOs are staged in RUNNER_TEMP (the runner work volume) one at a time —
# peak disk use is a single ISO (largest line ~11 GB EL dvd vs 25 Gi volume).
set -euo pipefail

selected="${1:?usage: upload-isos.sh <key|all>}"
tmpdir="${RUNNER_TEMP:-/tmp}"
datastore="$(grep -E '^common_iso_datastore ' ci/config/common.pkrvars.hcl | awk -F '"' '{print $2}')"

# Fail closed: a malformed matrix or zero enabled entries must fail the run,
# not silently upload nothing (process substitution discards jq's exit
# status). Also catches an empty datastore extraction.
jq -e 'type=="array" and ([.[] | select(.enabled)] | length > 0)' ci/matrix.json >/dev/null
test -n "$datastore"

matched=0
while IFS= read -r entry; do
	key="$(jq -r '.key' <<<"$entry")"
	if [ "$selected" != "all" ] && [ "$selected" != "$key" ]; then
		continue
	fi
	matched=$((matched + 1))
	iso_url="$(jq -r '.iso_url' <<<"$entry")"
	sums_url="$(jq -r '.sums_url' <<<"$entry")"
	ds_path="$(jq -r '.iso_datastore_path' <<<"$entry")"
	cfg="$(jq -r '.config' <<<"$entry")"
	file="$(basename "$iso_url")"

	if ! grep -q "\"${file}\"" "ci/config/${cfg}"; then
		echo "ERROR: ${file} (matrix iso_url) not found in ci/config/${cfg} — bump both together" >&2
		exit 1
	fi

	if [ -n "$(govc datastore.ls -ds "$datastore" "${ds_path}/${file}" 2>/dev/null)" ]; then
		echo "SKIP ${key}: [${datastore}] ${ds_path}/${file} already present"
		continue
	fi

	echo "DOWNLOAD ${key}: ${iso_url}"
	curl -fL --retry 3 -o "${tmpdir}/${file}" "$iso_url"

	# SUMS formats: coreutils "<hash>  <file>" (ubuntu/debian, file may be
	# *-prefixed) and BSD "SHA256 (<file>) = <hash>" (rocky/alma CHECKSUM —
	# algorithm-anchored: EL CHECKSUM files may list several algorithms).
	expected="$(curl -fL --retry 3 "$sums_url" | awk -v f="$file" \
		'($1 == "SHA256" && $2 == "(" f ")") {print $4} ($2 == f || $2 == "*" f) {print $1}' | head -n 1)"
	if [ -z "$expected" ]; then
		echo "ERROR: ${file} not found in ${sums_url}" >&2
		exit 1
	fi
	echo "${expected}  ${tmpdir}/${file}" | sha256sum -c -

	# Upload to a temp name, then rename into place (a same-datastore mv is a
	# metadata operation): an interrupted upload can only ever leave a
	# .partial object, which the existence check above ignores — the final
	# path never holds a truncated ISO.
	echo "UPLOAD ${key}: [${datastore}] ${ds_path}/${file}"
	govc datastore.upload -ds "$datastore" "${tmpdir}/${file}" "${ds_path}/.${file}.partial"
	govc datastore.mv -ds "$datastore" "${ds_path}/.${file}.partial" "${ds_path}/${file}"
	rm -f "${tmpdir}/${file}"
done < <(jq -c '.[] | select(.enabled)' ci/matrix.json)

if [ "$matched" -eq 0 ]; then
	echo "ERROR: no enabled matrix entry matched key '${selected}'" >&2
	exit 1
fi
