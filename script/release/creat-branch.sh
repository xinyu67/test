#!/bin/sh

function create_branch(){
    local MAIN_BRANCH='main'
    local BASE_VERSION=$1
    local NEW_VERSION=$2
    local TYPE=$4
    echo BASE_VERSION = $BASE_VERSION
    echo NEW_VERSION = $NEW_VERSION
    echo TYPE = $TYPE
    declare -a BR_ARRAY=("${!3}")
    for BRANCH in "${BR_ARRAY[@]}"; do
        echo "$BRANCH"
    done


    # Check params
    if [ -z "$BASE_VERSION" ]; then
        echo "Base version name not provided"
        return
    fi


    if [ -z "$NEW_VERSION" ]; then
        echo "New version name not provided"
        return
    fi


    if [ -z "$TYPE" ]; then
        echo "Type not specified"
        return
    fi


    if [ ! -n "$BR_ARRAY" ]; then
        echo "Branches not provided"
        return
    fi




    CHECK_TYPE=`declare -p BR_ARRAY | grep -q '^declare \-a' && echo array || echo no array`
    if [ CHECK_TYPE == "no array" ]; then
        echo "Branches not stored in array"
        return
    fi



    # Create release branch
    BRANCH_LOGS=()
    MERGED_BRANCHES=()
    BASE_TAG=`git tag -l | grep -E "(^|\s)$BASE_VERSION($|\s)"  | tail -1`

    if [ ! -z "$BASE_TAG" ]; then
        git -c advice.detachedHead=false checkout $BASE_TAG > /dev/null

        # Check if checkout command success
        if [ $? -eq 0 ]; then
            # Check if new version branch exist,than recreate one
            NEW_VERSION_BRANCH="$TYPE/$NEW_VERSION"
            CHECK_BRANCH_EXIST=`git branch -l | grep -E "(^|\s)$NEW_VERSION_BRANCH($|\s)"  | tail -1`

            if [ ! -z "$CHECK_BRANCH_EXIST" ]; then
            echo "Delete branch $NEW_VERSION_BRANCH"
            git branch -D $NEW_VERSION_BRANCH > /dev/null
            fi

            git checkout -b $NEW_VERSION_BRANCH
            MERGED_BRANCHES=("${MERGED_BRANCHES[@]}" "$NEW_VERSION_BRANCH")

            for BRANCH in "${BR_ARRAY[@]}"
            do
            CHECK_BRANCH_EXIST=`git branch -la | grep -E "origin/$BRANCH($|\s)"  | tail -1`
            if [ ! -z "$CHECK_BRANCH_EXIST" ]; then
                git merge origin/$BRANCH -m "resolve $BRANCH" > /dev/null
                if [ ! $? -eq 0 ]; then
                    git merge --abort

                    MESSAGE="$BRANCH;automatic_merge_failed,conflicted:"
                    #Check conflicted branches

                    CONFLICTED_BRANCHES=()
                    git -c advice.detachedHead=false checkout origin/$BRANCH > /dev/null

                    for MERGED_BRANCH in ${MERGED_BRANCHES[@]}; do
                        git merge --no-commit --no-ff $MERGED_BRANCH > /dev/null
                        if [ ! $? -eq 0 ]; then
                            echo "Merge $BRANCH to $MERGED_BRANCH failed"
                            MESSAGE="$MESSAGE$MERGED_BRANCH,"
                        fi
                        git checkout -f
                    done

                    BRANCH_LOGS=("${BRANCH_LOGS[@]}" "$MESSAGE")
                    git checkout $NEW_VERSION_BRANCH
                else
                    MESSAGE="$BRANCH;merged"
                    MERGED_BRANCHES=("${MERGED_BRANCHES[@]}" "origin/$BRANCH")
                    BRANCH_LOGS=("${BRANCH_LOGS[@]}" "$MESSAGE")
                fi
            else
                # BRANCH_LOGS+=("$BRANCH Not found")
                MESSAGE="$BRANCH;branch_not_found"
                BRANCH_LOGS=("${BRANCH_LOGS[@]}" "$MESSAGE")
            fi
            done


            echo "=== Merge Results ==="


            for LOG in ${BRANCH_LOGS[@]}; do

                CONTENT=(${LOG//;/ })

                printf "%-30s %s\n" "${CONTENT[0]}" " ${CONTENT[1]}"
            done

        fi

    else
        echo Base version not found
    fi
}

source scripts/release/${1}.sh

create_branch $BASE_VERSION ${1} BRANCHES[@] $TYPE