export BBFS_ROOT=$1

function mksymlink {
  # mksymlink --ref_cd=<path> --base_cd=<path> --dest=<path>
  ruby $BBFS_ROOT/fileutil.rb mksymlink $1 $2 $3
}

function merge {
  # merge --cd_a=<path> --cd_b=<path> --dest=<path>
  ruby $BBFS_ROOT/fileutil.rb merge $1 $2 $3
}

function intersect {
  # intersect --cd_a=<path> --cd_b=<path> --dest=<path>
  ruby $BBFS_ROOT/fileutil.rb intersect $1 $2 $3
}

function minus {
  # minus --cd_a=<path> --cd_b=<path> --dest=<path>
  ruby $BBFS_ROOT/fileutil.rb minus $1 $2 $3
}

function copy {
  # copy --conf=<path> --cd=<path> --dest_server=<server name> --dest_path=<dir>
  ruby $BBFS_ROOT/fileutil.rb copy $1 $2 $3 $4
}

function unify_time {
  # unify_time --cd=<path>
  ruby $BBFS_ROOT/fileutil.rb unify_time $1
}

function indexer {
  # indexer --patterns=<path> [--exist_cd=<path>]
  ruby $BBFS_ROOT/fileutil.rb indexer $1 $2
}

function crawler {
  # crawler --conf_file=<path> [--cd_out=<path>] [--cd_in=<path>]
  ruby $BBFS_ROOT/fileutil.rb crawler $1 $2 $3
}
