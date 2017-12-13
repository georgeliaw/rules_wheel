# rules_wheel
Bazel rule for building a python wheel.

This aims to simplify the wheel-building process by taking over the need to write and maintain extra `setup.py` files and then building via `genrule`.
Instead, you can use this rule to wrap that whole process for you.

You can check out the Skydoc-generated wheel docs [here](docs/wheel.md).

Unfortunately Skydoc doesn't currently support the newer `doc` label parameter,
so check out the Skylark source in [wheel.bzl](wheel/wheel.bzl) for more info.

# Installing and Usage
Currently requires having `setuptools` installed locally (will work on bringing that into the rule itself).

To use the wheel rule, you will need to add the following into your `WORKSPACE` file:
```
http_archive(
    name = "io_bazel_rules_wheel",
    strip_prefix = "rules_wheel-<version>",
    urls = ["https://github.com/georgeliaw/rules_wheel/archive/<version>.tar.gz"],
    sha256 = "<checksum>"
)
```

To load the rules, either do so in your `BUILD` files or simply add to `tools/build_rules/prelude_bazel`:
```
load("@io_bazel_rules_wheel//wheel:wheel.bzl", "bdist_wheel")
```
NOTE: using `prelude_bazel` requires an empty `tools/build_rules/BUILD` file.

You can now create wheels by doing something similar to the below:
```
bdist_wheel(
    name = "sample_wheel",
    srcs = glob(
        ["**"],
        exclude = ["**/*.pyc"],
    ),
    data = {
        '': ['**/*']
    }
)
```
