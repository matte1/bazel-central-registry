"""Stage a set of files into a single directory (TreeArtifact).

Needed because include_dir!() reads CARGO_MANIFEST_DIR as a *directory* at
compile time; we point CARGO_MANIFEST_DIR at this staged DB dir.
"""

def _db_tree_impl(ctx):
    out = ctx.actions.declare_directory(ctx.attr.dirname)
    src = ctx.file.anchor
    ctx.actions.run_shell(
        inputs = ctx.files.srcs,
        outputs = [out],
        command = 'set -e; root="$(dirname "%s")"; mkdir -p "%s"; cp -RL "$root"/* "%s"/' % (
            src.path,
            out.path,
            out.path,
        ),
        mnemonic = "StageDb",
        progress_message = "Staging prjoxide DB into a directory",
    )
    return [DefaultInfo(files = depset([out]))]

db_tree = rule(
    implementation = _db_tree_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "anchor": attr.label(allow_single_file = True, mandatory = True),
        "dirname": attr.string(default = "db_tree"),
    },
)
