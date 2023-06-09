#!/bin/bash
set -o pipefail

baseDirectory="${INPUT_BASE_DIRECTORY}"
providers="${INPUT_PROVIDERS}"
envs="${INPUT_ENVIRONMENTS}"
regions="${INPUT_REGIONS}"
resourceGroups="${INPUT_RESOURCE_GROUPS}"

function checkInputs() {
  files=( $(echo $INPUT_FILES | sed -e 's/\[//g' -e 's/\]//g' -e 's/\,//g') )
  globalFiles=( $(echo $INPUT_GLOBAL_FILES | sed -e 's/\[//g' -e 's/\]//g' -e 's/\,//g') )
  if [[ ! -d ${baseDirectory} ]]; then
    echo "::error::${baseDirectory} must exist in your repo!"
    exit 1
  fi
  if [[ -z ${files} ]]; then
    echo "::error::Files input cannot be null."
    exit 1
  elif [[ ${#files[@]} -eq 0 ]]; then
    echo "::error::The array passed to files input contained no items."
    exit 1
  fi
  if [[ ! ${#globalFiles[@]} -eq 0 ]]; then
    files+=(${globalFiles[@]})
    dupes=($(echo "${files[@]}" | tr ' ' "\n" | sort | uniq -d))

    if [ ! "${#dupes[@]}" -eq 0 ]; then
      echo "::warning::${#dupes[@]} Global files have been changed! All resource groups could be impacted."
      globalChange
    else
      main "${INPUT_FILES}"
    fi
  fi
}

function main() {
  inputFiles="${1}"
  query="$baseDirectory/(?<provider>$providers)/(?<env>$envs)/(?<region>$regions)/(?<resource_group>$resourceGroups)/"
  matrix=$(echo "${inputFiles}" | jq --arg query "${query}" '{include: map(select(values) | capture($query))|unique}')
  paths=$(echo "${matrix}" | jq --raw-output '.include[] | "| " + .["provider"] + " | " + .["env"] + " | " + .["region"] + " | " + .["resource_group"] + " |"')

  echo ${matrix}
  echo "matrix=$(echo ${matrix[@]} | jq -s -c -r .[])" >> $GITHUB_OUTPUT
  echo "# Builds" >> $GITHUB_STEP_SUMMARY
  echo "| Provider | Env | Region | Resource Group |" >> $GITHUB_STEP_SUMMARY
  echo "| -------- | --- | ------ | -------------- |" >> $GITHUB_STEP_SUMMARY
  echo "${paths}" >> $GITHUB_STEP_SUMMARY
}

function globalChange() {
  files=($(find ${baseDirectory} -type f))
  printf -v joined '"%s", ' "${files[@]}"

  allFiles=$(echo "[${joined%s,}\"ignore\"]")
  main "${allFiles}"
}

checkInputs
