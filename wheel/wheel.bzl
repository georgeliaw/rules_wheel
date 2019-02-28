"""Bazel rule for building a python wheel"""

def _generate_setup_py(ctx):
    classifiers = "[{}]".format(",".join(['"{}"'.format(i) for i in ctx.attr.classifiers]))
    install_requires = "[{}]".format(",".join(['"{}"'.format(i) for i in ctx.attr.install_requires]))
    setup_py = ctx.actions.declare_file("{}/setup.py".format(ctx.attr.name))

    # create setup.py
    ctx.actions.expand_template(
        template = ctx.file._setup_py_template,
        output = setup_py,
        substitutions = {
            "{name}": ctx.attr.name,
            "{version}": ctx.attr.version,
            "{description}": ctx.attr.description,
            "{classifiers}": classifiers,
            "{platforms}": str(ctx.attr.platform),
            "{package_data}": str(ctx.attr.data),
            "{include_package_data}": str(ctx.attr.include_package_data),
            "{install_requires}": install_requires,
        },
        is_executable = True,
    )

    return setup_py

def _generate_manifest(ctx, package_name):
    manifest_text = "\n".join([i for i in ctx.attr.manifest]).format(package_name = package_name)

    manifest = ctx.actions.declare_file("{}/MANIFEST.in".format(ctx.attr.name))
    ctx.actions.expand_template(
        template = ctx.file._manifest_template,
        output = manifest,
        substitutions = {
            "{manifest}": manifest_text,
        },
        is_executable = True,
    )

    return manifest

def _bdist_wheel_impl(ctx):
    # use the rule name in the work dir path in case multiple wheels are declared in the same BUILD file
    work_dir = "{}/wheel".format(ctx.attr.name)
    build_file_dir = ctx.build_file_path.rstrip("/BUILD")

    package_dir = ctx.actions.declare_directory(work_dir)
    package_name = package_dir.dirname.split("/")[-1]

    setup_py_dest_dir = "/".join([
        package_dir.path,
        "/".join(build_file_dir.split("/")[:-1]),
        ctx.attr.strip_src_prefix.strip("/"),
    ])
    backtrack_path = "/".join([".." for i in setup_py_dest_dir.split("/") if i])

    setup_py = _generate_setup_py(ctx)
    manifest = _generate_manifest(ctx, package_name)

    source_list = " ".join([src.path for src in ctx.files.srcs])

    ctx.actions.run_shell(
        mnemonic = "CreateWorkDir",
        outputs = [package_dir],
        inputs = [],
        command = "mkdir -p {package_dir}".format(package_dir = package_dir.path),
    )

    command = "chmod 0775 {package_dir} " + \
              "&& rsync -R {source_list} {package_dir} " + \
              "&& cp {setup_py_path} {setup_py_dest_dir} " + \
              "&& cp {manifest_path} {setup_py_dest_dir} " + \
              "&& cd {setup_py_dest_dir} " + \
              "&& python setup.py bdist_wheel --universal --dist-dir {dist_dir} "

    ctx.actions.run_shell(
        mnemonic = "BuildWheel",
        outputs = [ctx.outputs.wheel],
        inputs = ctx.files.srcs + [package_dir, setup_py, manifest],
        command = command.format(
            source_list = source_list,
            setup_py_path = setup_py.path,
            manifest_path = manifest.path,
            package_dir = package_dir.path,
            setup_py_dest_dir = setup_py_dest_dir,
            bdist_dir = package_dir.path + "/build",
            dist_dir = backtrack_path + "/" + ctx.outputs.wheel.dirname,
        ),
    )

    return DefaultInfo(files = depset([ctx.outputs.wheel]))

_bdist_wheel_attrs = {
    "srcs": attr.label_list(
        doc = "Source files to include in the wheel",
        allow_files = [".py"],
        mandatory = True,
        allow_empty = False,
    ),
    "strip_src_prefix": attr.string(
        doc = "Path prefix to strip from the files listed in srcs if the build rule is not in the root directory of the source files. External sources will require at least `external/` to be stripped",
        mandatory = False,
    ),
    "version": attr.string(
        default = "0.0.1",
        doc = "Version to be assigned to the wheel.",
        mandatory = False,
    ),
    "description": attr.string(
        doc = "Short description of the wheel, no more than 200 characters.",
        mandatory = False,
    ),
    "classifiers": attr.string_list(
        doc = "Classifiers for the wheel.",
        mandatory = False,
    ),
    "platform": attr.string_list(
        default = ["any"],
        doc = "Platform the wheel is being built for.",
        mandatory = False,
    ),
    "data": attr.string_list_dict(
        doc = "A dictionary that maps packages to lists of glob patterns of non-python files listed in `srcs` to include in the wheel.",
        mandatory = False,
    ),
    "manifest": attr.string_list(
        default = ["recursive-include {package_name} *"],
        doc = "List of statements to insert into the MANIFEST.in file.",
        mandatory = False,
    ),
    "include_package_data": attr.bool(
        default = False,
        doc = "Whether to use the setuptools `include_package_data` setting. Note that if used with `data`, only data files specified in `manifest` will be included.",
        mandatory = False,
    ),
    "install_requires": attr.string_list(
        doc = "A list of strings specifying what other wheels need to be installed when this one is.",
        mandatory = False,
    ),
    "_setup_py_template": attr.label(
        default = Label("//wheel:setup.py.template"),
        allow_single_file = True,
    ),
    "_manifest_template": attr.label(
        default = Label("//wheel:MANIFEST.in.template"),
        allow_single_file = True,
    ),
}

_bdist_wheel_outputs = {
    "wheel": "%{name}-%{version}-py2.py3-none-%{platform}.whl",
}

bdist_wheel = rule(
    implementation = _bdist_wheel_impl,
    executable = False,
    attrs = _bdist_wheel_attrs,
    outputs = _bdist_wheel_outputs,
)
