# [Serialization semantics](https://docs.pytorch.org/docs/stable/notes/serialization.html#id5)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#serialization-semantics "Link to this heading")

Created On: Feb 26, 2017 | Last Updated On: Oct 27, 2025

This note describes how you can save and load PyTorch tensors and module states in Python, and how to serialize Python modules so they can be loaded in C++.

Table of Contents

-   [Serialization semantics](https://docs.pytorch.org/docs/stable/notes/serialization.html#serialization-semantics)
    
    -   [Saving and loading tensors](https://docs.pytorch.org/docs/stable/notes/serialization.html#saving-and-loading-tensors)
    -   [Saving and loading tensors preserves views](https://docs.pytorch.org/docs/stable/notes/serialization.html#saving-and-loading-tensors-preserves-views)
    -   [Saving and loading torch.nn.Modules](https://docs.pytorch.org/docs/stable/notes/serialization.html#saving-and-loading-torch-nn-modules)
    -   [Serialized file format for `torch.save`](https://docs.pytorch.org/docs/stable/notes/serialization.html#serialized-file-format-for-torch-save)
    -   [Layout Control](https://docs.pytorch.org/docs/stable/notes/serialization.html#layout-control)
    -   [`torch.load` with `weights_only=True`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch-load-with-weights-only-true)
        
        -   [weights\_only security](https://docs.pytorch.org/docs/stable/notes/serialization.html#weights-only-security)
        -   [weights\_only allowlist](https://docs.pytorch.org/docs/stable/notes/serialization.html#weights-only-allowlist)
        -   [Troubleshooting `weights_only`](https://docs.pytorch.org/docs/stable/notes/serialization.html#troubleshooting-weights-only)
            
            -   [Getting unsafe globals](https://docs.pytorch.org/docs/stable/notes/serialization.html#getting-unsafe-globals)
            -   [Environment Variables](https://docs.pytorch.org/docs/stable/notes/serialization.html#environment-variables)
    -   [Utility functions](https://docs.pytorch.org/docs/stable/notes/serialization.html#utility-functions)
    -   [Config](https://docs.pytorch.org/docs/stable/notes/serialization.html#module-torch.utils.serialization)

## [Saving and loading tensors](https://docs.pytorch.org/docs/stable/notes/serialization.html#id6)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#saving-and-loading-tensors "Link to this heading")

[`torch.save()`](https://docs.pytorch.org/docs/stable/generated/torch.save.html#torch.save "torch.save") and [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load") let you easily save and load tensors:

\>>> t \= torch.tensor(\[1., 2.\])
\>>> torch.save(t, 'tensor.pt')
\>>> torch.load('tensor.pt')
tensor(\[1., 2.\])

Copy to clipboard

By convention, PyTorch files are typically written with a ‘.pt’ or ‘.pth’ extension.

[`torch.save()`](https://docs.pytorch.org/docs/stable/generated/torch.save.html#torch.save "torch.save") and [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load") use Python’s pickle by default, so you can also save multiple tensors as part of Python objects like tuples, lists, and dicts:

\>>> d \= {'a': torch.tensor(\[1., 2.\]), 'b': torch.tensor(\[3., 4.\])}
\>>> torch.save(d, 'tensor\_dict.pt')
\>>> torch.load('tensor\_dict.pt')
{'a': tensor(\[1., 2.\]), 'b': tensor(\[3., 4.\])}

Copy to clipboard

Custom data structures that include PyTorch tensors can also be saved if the data structure is pickle-able.

## [Saving and loading tensors preserves views](https://docs.pytorch.org/docs/stable/notes/serialization.html#id7)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#saving-and-loading-tensors-preserves-views "Link to this heading")

Saving tensors preserves their view relationships:

\>>> numbers \= torch.arange(1, 10)
\>>> evens \= numbers\[1::2\]
\>>> torch.save(\[numbers, evens\], 'tensors.pt')
\>>> loaded\_numbers, loaded\_evens \= torch.load('tensors.pt')
\>>> loaded\_evens \*= 2
\>>> loaded\_numbers
tensor(\[ 1,  4,  3,  8,  5, 12,  7, 16,  9\])

Copy to clipboard

Behind the scenes, these tensors share the same “storage.” See [Tensor Views](https://pytorch.org/docs/main/tensor_view.html) for more on views and storage.

When PyTorch saves tensors it saves their storage objects and tensor metadata separately. This is an implementation detail that may change in the future, but it typically saves space and lets PyTorch easily reconstruct the view relationships between the loaded tensors. In the above snippet, for example, only a single storage is written to ‘tensors.pt’.

In some cases, however, saving the current storage objects may be unnecessary and create prohibitively large files. In the following snippet a storage much larger than the saved tensor is written to a file:

\>>> large \= torch.arange(1, 1000)
\>>> small \= large\[0:5\]
\>>> torch.save(small, 'small.pt')
\>>> loaded\_small \= torch.load('small.pt')
\>>> loaded\_small.storage().size()
999

Copy to clipboard

Instead of saving only the five values in the small tensor to ‘small.pt,’ the 999 values in the storage it shares with large were saved and loaded.

When saving tensors with fewer elements than their storage objects, the size of the saved file can be reduced by first cloning the tensors. Cloning a tensor produces a new tensor with a new storage object containing only the values in the tensor:

\>>> large \= torch.arange(1, 1000)
\>>> small \= large\[0:5\]
\>>> torch.save(small.clone(), 'small.pt')  \# saves a clone of small
\>>> loaded\_small \= torch.load('small.pt')
\>>> loaded\_small.storage().size()
5

Copy to clipboard

Since the cloned tensors are independent of each other, however, they have none of the view relationships the original tensors did. If both file size and view relationships are important when saving tensors smaller than their storage objects, then care must be taken to construct new tensors that minimize the size of their storage objects but still have the desired view relationships before saving.

## [Saving and loading torch.nn.Modules](https://docs.pytorch.org/docs/stable/notes/serialization.html#id8)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#saving-and-loading-torch-nn-modules "Link to this heading")

See also: [Tutorial: Saving and loading modules](https://pytorch.org/tutorials/beginner/saving_loading_models.html)

In PyTorch, a module’s state is frequently serialized using a ‘state dict.’ A module’s state dict contains all of its parameters and persistent buffers:

\>>> bn \= torch.nn.BatchNorm1d(3, track\_running\_stats\=True)
\>>> list(bn.named\_parameters())
\[('weight', Parameter containing: tensor(\[1., 1., 1.\], requires\_grad=True)),
 ('bias', Parameter containing: tensor(\[0., 0., 0.\], requires\_grad=True))\]

\>>> list(bn.named\_buffers())
\[('running\_mean', tensor(\[0., 0., 0.\])),
 ('running\_var', tensor(\[1., 1., 1.\])),
 ('num\_batches\_tracked', tensor(0))\]

\>>> bn.state\_dict()
OrderedDict(\[('weight', tensor(\[1., 1., 1.\])),
             ('bias', tensor(\[0., 0., 0.\])),
             ('running\_mean', tensor(\[0., 0., 0.\])),
             ('running\_var', tensor(\[1., 1., 1.\])),
             ('num\_batches\_tracked', tensor(0))\])

Copy to clipboard

Instead of saving a module directly, for compatibility reasons it is recommended to instead save only its state dict. Python modules even have a function, [`load_state_dict()`](https://docs.pytorch.org/docs/stable/generated/torch.nn.Module.html#torch.nn.Module.load_state_dict "torch.nn.Module.load_state_dict"), to restore their states from a state dict:

\>>> torch.save(bn.state\_dict(), 'bn.pt')
\>>> bn\_state\_dict \= torch.load('bn.pt')
\>>> new\_bn \= torch.nn.BatchNorm1d(3, track\_running\_stats\=True)
\>>> new\_bn.load\_state\_dict(bn\_state\_dict)
<All keys matched successfully>

Copy to clipboard

Note that the state dict is first loaded from its file with [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load") and the state then restored with [`load_state_dict()`](https://docs.pytorch.org/docs/stable/generated/torch.nn.Module.html#torch.nn.Module.load_state_dict "torch.nn.Module.load_state_dict").

Even custom modules and modules containing other modules have state dicts and can use this pattern:

\# A module with two linear layers
\>>> class MyModule(torch.nn.Module):
      def \_\_init\_\_(self):
        super().\_\_init\_\_()
        self.l0 \= torch.nn.Linear(4, 2)
        self.l1 \= torch.nn.Linear(2, 1)

      def forward(self, input):
        out0 \= self.l0(input)
        out0\_relu \= torch.nn.functional.relu(out0)
        return self.l1(out0\_relu)

\>>> m \= MyModule()
\>>> m.state\_dict()
OrderedDict(\[('l0.weight', tensor(\[\[ 0.1400, 0.4563, \-0.0271, \-0.4406\],
                                   \[\-0.3289, 0.2827, 0.4588, 0.2031\]\])),
             ('l0.bias', tensor(\[ 0.0300, \-0.1316\])),
             ('l1.weight', tensor(\[\[0.6533, 0.3413\]\])),
             ('l1.bias', tensor(\[\-0.1112\]))\])

\>>> torch.save(m.state\_dict(), 'mymodule.pt')
\>>> m\_state\_dict \= torch.load('mymodule.pt')
\>>> new\_m \= MyModule()
\>>> new\_m.load\_state\_dict(m\_state\_dict)
<All keys matched successfully\>

Copy to clipboard

## [Serialized file format for `torch.save`](https://docs.pytorch.org/docs/stable/notes/serialization.html#id9)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#serialized-file-format-for-torch-save "Link to this heading")

Since PyTorch 1.6.0, `torch.save` defaults to returning an uncompressed ZIP64 archive unless the user sets `_use_new_zipfile_serialization=False`.

In this archive, the files are ordered as such

checkpoint.pth
├── data.pkl
├── byteorder  # added in PyTorch 2.1.0
├── data/
│   ├── 0
│   ├── 1
│   ├── 2
│   └── …
└── version

Copy to clipboard

The entries are as follows:

-   `data.pkl` is the result of pickling the object passed to `torch.save` excluding `torch.Storage` objects that it contains
-   `byteorder` contains a string with the `sys.byteorder` when saving (“little” or “big”)
-   `data/` contains all the storages in the object, where each storage is a separate file
-   `version` contains a version number at save time that can be used at load time

When saving, PyTorch will ensure that the local file header of each file is padded to an offset that is a multiple of 64 bytes, ensuring that the offset of each file is 64-byte aligned.

Note

Tensors on certain devices such as XLA are serialized as pickled numpy arrays. As such, their storages are not serialized. In these cases `data/` might not exist in the checkpoint.

## [Layout Control](https://docs.pytorch.org/docs/stable/notes/serialization.html#id10)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#layout-control "Link to this heading")

The `mmap` argument in [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load") allows for lazy loading of tensor storages.

In addition, there are some advanced features that allow for more fine-grained control and manipulation of a `torch.save` checkpoint.

The [`torch.serialization.skip_data`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.skip_data "torch.serialization.skip_data") context manager enables

-   Saving a checkpoint with `torch.save` that includes empty space for data bytes to be written later.
-   Loading a checkpoint with `torch.load` and filling in the data bytes of tensors later.

To inspect tensor metadata in a `torch.save` checkpoint without allocating memory for storage data, use `torch.load` within the `FakeTensorMode` context manager. On top of skipping loading storage data similar to `skip_data` above, it additionally tags storages with their offset within the checkpoint, enabling direct checkpoint manipulation.

import torch.nn as nn
from torch.\_subclasses.fake\_tensor import FakeTensorMode

m \= nn.Linear(10, 10)
torch.save(m.state\_dict(), "checkpoint.pt")

with FakeTensorMode() as mode:
    fake\_sd \= torch.load("checkpoint.pt")

for k, v in fake\_sd.items():
    print(f"key={k}, dtype={v.dtype}, shape={v.shape}, stride={v.stride()}, storage\_offset={v.storage\_offset()}")
    \# offset of the storage in the checkpoint
    print(f"key={k}, checkpoint\_offset={v.untyped\_storage().\_checkpoint\_offset}")

Copy to clipboard

For more information, [this tutorial](https://docs.pytorch.org/tutorials/prototype/gpu_direct_storage.html) offers a comprehensive example of using these features to manipulate a checkpoint.

## [`torch.load` with `weights_only=True`](https://docs.pytorch.org/docs/stable/notes/serialization.html#id11)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch-load-with-weights-only-true "Link to this heading")

Starting in version 2.6, `torch.load` will use `weights_only=True` if the `pickle_module` argument is not passed.

### [weights\_only security](https://docs.pytorch.org/docs/stable/notes/serialization.html#id12)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#weights-only-security "Link to this heading")

As discussed in the documentation for [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load"), `weights_only=True` restricts the unpickler used in `torch.load` to only executing functions/building classes required for `state_dicts` of plain `torch.Tensors` as well as some other primitive types. Further, unlike the default `Unpickler` provided by the `pickle` module, the `weights_only` Unpickler is not allowed to dynamically import anything during unpickling.

`weights_only=True` narrows the surface of remote code execution attacks but has the following limitations:

1.  `weights_only=True` does not guard against denial of service attacks.
2.  We try to prevent memory corruptions during `torch.load(weights_only=True)` but they might still be possible.

Note that even if memory corruption does not occur during `torch.load` itself, loading CAN create unexpected objects for the downstream code that can also lead to memory corruption (e.g. a Tensor of indices and values made to a sparse Tensor in user code might write/read out of bounds).

### [weights\_only allowlist](https://docs.pytorch.org/docs/stable/notes/serialization.html#id13)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#weights-only-allowlist "Link to this heading")

As mentioned above, saving a module’s `state_dict` is a best practice when using `torch.save`. If loading an old checkpoint that contains an `nn.Module`, we recommend `weights_only=False`. When loading a checkpoint that contains tensor subclasses, there will likely be functions/classes that need to be allowlisted, see below for further details.

If the `weights_only` Unpickler encounters a function or class that is not allowlisted by default within the pickle file, you should see an actionable error like such

\_pickle.UnpicklingError: Weights only load failed. This file can still be loaded,
to do so you have two options, do those steps only if you trust the source of the checkpoint.
    1. Re-running \`torch.load\` with \`weights\_only\` set to \`False\` will likely succeed,
        but it can result in arbitrary code execution. Do it only if you got the file from a trusted source.
    2. Alternatively, to load with \`weights\_only=True\` please check the recommended
       steps in the following error message.
       WeightsUnpickler error: Unsupported global: GLOBAL {\_\_module\_\_}.{\_\_name\_\_} was not an allowed global by
       default. Please use \`torch.serialization.add\_safe\_globals(\[{\_\_name\_\_}\])\` or the
       \`torch.serialization.safe\_globals(\[{\_\_name\_\_}\])\` context manager to allowlist this global
       if you trust this class/function.

Copy to clipboard

Please follow the steps in the error message and allowlist the functions or classes only if you trust them.

To get all GLOBALs (functions/classes) in the checkpoint that are not yet allowlisted you can use [`torch.serialization.get_unsafe_globals_in_checkpoint()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_unsafe_globals_in_checkpoint "torch.serialization.get_unsafe_globals_in_checkpoint") which will return a list of strings of the form `{__module__}.{__name__}`. If you trust these functions/classes, you can import them and allowlist them per the error message either via [`torch.serialization.add_safe_globals()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.add_safe_globals "torch.serialization.add_safe_globals") or the context manager [`torch.serialization.safe_globals`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.safe_globals "torch.serialization.safe_globals").

To access the list of user-allowlisted functions/classes you can use [`torch.serialization.get_safe_globals()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_safe_globals "torch.serialization.get_safe_globals") and to clear the current list see [`torch.serialization.clear_safe_globals()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.clear_safe_globals "torch.serialization.clear_safe_globals").

### [Troubleshooting `weights_only`](https://docs.pytorch.org/docs/stable/notes/serialization.html#id14)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#troubleshooting-weights-only "Link to this heading")

#### [Getting unsafe globals](https://docs.pytorch.org/docs/stable/notes/serialization.html#id15)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#getting-unsafe-globals "Link to this heading")

A caveat is that [`torch.serialization.get_unsafe_globals_in_checkpoint()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_unsafe_globals_in_checkpoint "torch.serialization.get_unsafe_globals_in_checkpoint") analyzes the checkpoint statically, some types might be built dynamically during the unpickling process and hence will not be reported by [`torch.serialization.get_unsafe_globals_in_checkpoint()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_unsafe_globals_in_checkpoint "torch.serialization.get_unsafe_globals_in_checkpoint"). One such example is `dtypes` in numpy. In `numpy < 1.25` after allowlisting all the functions/classes reported by [`torch.serialization.get_unsafe_globals_in_checkpoint()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_unsafe_globals_in_checkpoint "torch.serialization.get_unsafe_globals_in_checkpoint") you might see an error like

WeightsUnpickler error: Can only build Tensor, Parameter, OrderedDict or types allowlisted via \`add\_safe\_globals\`,
but got <class 'numpy.dtype\[float32\]'>

Copy to clipboard

This can be allowlisted via `{add_}safe_globals([type(np.dtype(np.float32))])`.

In `numpy >=1.25` you would see

WeightsUnpickler error: Can only build Tensor, Parameter, OrderedDict or types allowlisted via \`add\_safe\_globals\`,
but got <class 'numpy.dtypes.Float32DType'>

Copy to clipboard

This can be allowlisted via `{add_}safe_globals([np.dtypes.Float32DType])`.

#### [Environment Variables](https://docs.pytorch.org/docs/stable/notes/serialization.html#id16)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#environment-variables "Link to this heading")

There are two environment variables that will influence the behavior of `torch.load`. These can be helpful if one does not have access to the `torch.load` callsites.

-   `TORCH_FORCE_WEIGHTS_ONLY_LOAD=1` will override all `torch.load` callsites to use `weights_only=True`.
-   `TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1` will make `torch.load` callsites use `weights_only=False` **only** if `weights_only` was not passed as an argument.

## [Utility functions](https://docs.pytorch.org/docs/stable/notes/serialization.html#id17)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#utility-functions "Link to this heading")

The following utility functions are related to serialization:

torch.serialization.register\_package(_priority_, _tagger_, _deserializer_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L444)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.register_package "Link to this definition")

Registers callables for tagging and deserializing storage objects with an associated priority. Tagging associates a device with a storage object at save time while deserializing moves a storage object to an appropriate device at load time. `tagger` and `deserializer` are run in the order given by their `priority` until a tagger/deserializer returns a value that is not None.

To override the deserialization behavior for a device in the global registry, one can register a tagger with a higher priority than the existing tagger.

This function can also be used to register a tagger and deserializer for new devices.

Parameters:

-   **priority** ([_int_](https://docs.python.org/3/library/functions.html#int "(in Python v3.14)")) – Indicates the priority associated with the tagger and deserializer, where a lower value indicates higher priority.
-   **tagger** ([_Callable_](https://docs.python.org/3/library/collections.abc.html#collections.abc.Callable "(in Python v3.14)")_\[__\[__Storage_ _|_ [_TypedStorage_](https://docs.pytorch.org/docs/stable/storage.html#torch.TypedStorage "torch.storage.TypedStorage") _|_ [_UntypedStorage_](https://docs.pytorch.org/docs/stable/storage.html#torch.UntypedStorage "torch.storage.UntypedStorage")_\]__,_ [_str_](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)") _|_ _None__\]_) – Callable that takes in a storage object and returns its tagged device as a string or None.
-   **deserializer** ([_Callable_](https://docs.python.org/3/library/collections.abc.html#collections.abc.Callable "(in Python v3.14)")_\[__\[__Storage_ _|_ [_TypedStorage_](https://docs.pytorch.org/docs/stable/storage.html#torch.TypedStorage "torch.storage.TypedStorage") _|_ [_UntypedStorage_](https://docs.pytorch.org/docs/stable/storage.html#torch.UntypedStorage "torch.storage.UntypedStorage")_,_ [_str_](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)")_\]__,_ _Storage_ _|_ [_TypedStorage_](https://docs.pytorch.org/docs/stable/storage.html#torch.TypedStorage "torch.storage.TypedStorage") _|_ [_UntypedStorage_](https://docs.pytorch.org/docs/stable/storage.html#torch.UntypedStorage "torch.storage.UntypedStorage") _|_ _None__\]_) – Callable that takes in storage object and a device string and returns a storage object on the appropriate device or None.

Returns:

None

Example

\>>> def ipu\_tag(obj):
\>>>     if obj.device.type \== 'ipu':
\>>>         return 'ipu'
\>>> def ipu\_deserialize(obj, location):
\>>>     if location.startswith('ipu'):
\>>>         ipu \= getattr(torch, "ipu", None)
\>>>         assert ipu is not None, "IPU device module is not loaded"
\>>>         assert torch.ipu.is\_available(), "ipu is not available"
\>>>         return obj.ipu(location)
\>>> torch.serialization.register\_package(11, ipu\_tag, ipu\_deserialize)

Copy to clipboard

torch.serialization.get\_crc32\_options()[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L172)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_crc32_options "Link to this definition")

Get whether [`torch.save()`](https://docs.pytorch.org/docs/stable/generated/torch.save.html#torch.save "torch.save") computes and writes crc32 for each record.

Defaults to `True`.

Return type:

[bool](https://docs.python.org/3/library/functions.html#bool "(in Python v3.14)")

torch.serialization.set\_crc32\_options(_compute\_crc32_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L183)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.set_crc32_options "Link to this definition")

Set whether [`torch.save()`](https://docs.pytorch.org/docs/stable/generated/torch.save.html#torch.save "torch.save") computes and writes crc32 for each record.

Note

Setting this to `False` may make unzipping of the `torch.save` output fail or warn due to corrupted CRC32. However `torch.load` will be able to load the file.

Parameters:

**compute\_crc32** ([_bool_](https://docs.python.org/3/library/functions.html#bool "(in Python v3.14)")) – set crc32 computation flag

torch.serialization.get\_default\_load\_endianness()[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L138)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_default_load_endianness "Link to this definition")

Get fallback byte order for loading files

If byteorder mark is not present in saved checkpoint, this byte order is used as fallback. By default, it’s “native” byte order.

Returns:

Optional\[LoadEndianness\]

Return type:

default\_load\_endian

torch.serialization.set\_default\_load\_endianness(_endianness_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L154)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.set_default_load_endianness "Link to this definition")

Set fallback byte order for loading files

If byteorder mark is not present in saved checkpoint, this byte order is used as fallback. By default, it’s “native” byte order.

Parameters:

**endianness** – the new fallback byte order

torch.serialization.get\_default\_mmap\_options()[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L200)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_default_mmap_options "Link to this definition")

Get default mmap options for [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load") with `mmap=True`.

Defaults to `mmap.MAP_PRIVATE`.

Returns:

int

Return type:

default\_mmap\_options

torch.serialization.set\_default\_mmap\_options(_flags_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L229)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.set_default_mmap_options "Link to this definition")

Context manager or function to set default mmap options for [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load") with `mmap=True` to flags.

For now, only either `mmap.MAP_PRIVATE` or `mmap.MAP_SHARED` are supported. Please open an issue if you need any other option to be added here.

Note

This feature is currently not supported for Windows.

Parameters:

**flags** ([_int_](https://docs.python.org/3/library/functions.html#int "(in Python v3.14)")) – `mmap.MAP_PRIVATE` or `mmap.MAP_SHARED`

torch.serialization.add\_safe\_globals(_safe\_globals_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L282)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.add_safe_globals "Link to this definition")

Marks the given globals as safe for `weights_only` load. For example, functions added to this list can be called during unpickling, classes could be instantiated and have state set.

Each item in the list can either be a function/class or a tuple of the form (function/class, string) where string is the full path of the function/class.

Within the serialized format, each function is identified with its full path as `{__module__}.{__qualname__}`. When calling this API, you can provide this full path that should match the one in the checkpoint otherwise the default `{fn.__module__}.{fn.__qualname__}` will be used.

Parameters:

**safe\_globals** (_List__\[__Union__\[__Callable__,_ _Tuple__\[__Callable__,_ [_str_](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)")_\]__\]__\]_) – list of globals to mark as safe

Example

\>>> import tempfile
\>>> class MyTensor(torch.Tensor):
...     pass
\>>> t \= MyTensor(torch.randn(2, 3))
\>>> with tempfile.NamedTemporaryFile() as f:
...     torch.save(t, f.name)
\# Running \`torch.load(f.name, weights\_only=True)\` will fail with
\# Unsupported global: GLOBAL \_\_main\_\_.MyTensor was not an allowed global by default.
\# Check the code and make sure MyTensor is safe to be used when loaded from an arbitrary checkpoint.
...     torch.serialization.add\_safe\_globals(\[MyTensor\])
...     torch.load(f.name, weights\_only\=True)
\# MyTensor(\[\[-0.5024, -1.8152, -0.5455\],
\#          \[-0.8234,  2.0500, -0.3657\]\])

Copy to clipboard

torch.serialization.clear\_safe\_globals()[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L268)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.clear_safe_globals "Link to this definition")

Clears the list of globals that are safe for `weights_only` load.

torch.serialization.get\_safe\_globals()[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L275)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_safe_globals "Link to this definition")

Returns the list of user-added globals that are safe for `weights_only` load.

Return type:

[list](https://docs.python.org/3/library/stdtypes.html#list "(in Python v3.14)")\[[_Callable_](https://docs.python.org/3/library/collections.abc.html#collections.abc.Callable "(in Python v3.14)") | [tuple](https://docs.python.org/3/library/stdtypes.html#tuple "(in Python v3.14)")\[[_Callable_](https://docs.python.org/3/library/collections.abc.html#collections.abc.Callable "(in Python v3.14)"), [str](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)")\]\]

torch.serialization.get\_unsafe\_globals\_in\_checkpoint(_f_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L343)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.get_unsafe_globals_in_checkpoint "Link to this definition")

Returns a list of strings of functions/classes in a `torch.save` object that are not safe for `weights_only`.

For a given function or class `f`, the corresponding string will be of the form `{f.__module__}.{f.__name__}`.

This function will return any GLOBALs in the checkpoint that are not in the set marked safe for `weights_only` (either via [`add_safe_globals()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.add_safe_globals "torch.serialization.add_safe_globals") or [`safe_globals`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.safe_globals "torch.serialization.safe_globals") context or allowlisted by `torch` by default).

Note

This function will statically disassemble the pickle file in the checkpoint. The implication is any classes dynamically pushed onto the stack during unpickling will not be included in the output.

Parameters:

**f** ([_str_](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)") _|_ [_PathLike_](https://docs.python.org/3/library/os.html#os.PathLike "(in Python v3.14)")_\[_[_str_](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)")_\]_ _|_ [_IO_](https://docs.python.org/3/library/typing.html#typing.IO "(in Python v3.14)")_\[_[_bytes_](https://docs.python.org/3/library/stdtypes.html#bytes "(in Python v3.14)")_\]_) – File-like object or string containing the checkpoint object saved via `torch.save`

Returns:

A list of strings of pickle GLOBALs in the checkpoint that are not allowlisted for `weights_only`.

Return type:

[list](https://docs.python.org/3/library/stdtypes.html#list "(in Python v3.14)")\[[str](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)")\]

_class_ torch.serialization.safe\_globals(_safe\_globals_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L318)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.safe_globals "Link to this definition")

Context-manager that adds certain globals as safe for `weights_only` load.

Parameters:

**safe\_globals** ([_list_](https://docs.python.org/3/library/stdtypes.html#list "(in Python v3.14)")_\[_[_Callable_](https://docs.python.org/3/library/collections.abc.html#collections.abc.Callable "(in Python v3.14)") _|_ [_tuple_](https://docs.python.org/3/library/stdtypes.html#tuple "(in Python v3.14)")_\[_[_Callable_](https://docs.python.org/3/library/collections.abc.html#collections.abc.Callable "(in Python v3.14)")_,_ [_str_](https://docs.python.org/3/library/stdtypes.html#str "(in Python v3.14)")_\]__\]_) – List of globals for weights\_only load.

Example

\>>> import tempfile
\>>> class MyTensor(torch.Tensor):
...     pass
\>>> t \= MyTensor(torch.randn(2, 3))
\>>> with tempfile.NamedTemporaryFile() as f:
...     torch.save(t, f.name)
\# Running \`torch.load(f.name, weights\_only=True)\` will fail with
\# Unsupported global: GLOBAL \_\_main\_\_.MyTensor was not an allowed global by default.
\# Check the code and make sure MyTensor is safe to be used when loaded from an arbitrary checkpoint.
...     with torch.serialization.safe\_globals(\[MyTensor\]):
...         torch.load(f.name, weights\_only\=True)
\# MyTensor(\[\[-0.5024, -1.8152, -0.5455\],
\#          \[-0.8234,  2.0500, -0.3657\]\])
\>>> assert torch.serialization.get\_safe\_globals() \== \[\]

Copy to clipboard

_class_ torch.serialization.skip\_data(_materialize\_fake\_tensors\=False_)[\[source\]](https://github.com/pytorch/pytorch/blob/v2.11.0/torch/serialization.py#L385)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.skip_data "Link to this definition")

Context-manager that skips writing/reading storage bytes for `torch.save` / `torch.load` calls.

For the save path, storages will still be saved, but the space that their bytes would usually be written to will be empty space. The storage bytes can then be populated in a separate pass.

For the load path, tensors will be loaded per the checkpoint but their storages will not be populated with data.

Warning

The `skip_data` context manager is an early prototype and is subject to change.

Parameters:

**materialize\_fake\_tensors** ([_bool_](https://docs.python.org/3/library/functions.html#bool "(in Python v3.14)")) – Whether to materialize FakeTensors during save. This is a no-op for the load path.

Example

\>>> import tempfile
\>>> t \= torch.randn(2, 3)
\>>> with tempfile.NamedTemporaryFile() as f:
...     with torch.serialization.skip\_data():
...         torch.save(t, f.name)
...     torch.load(f.name, weights\_only\=True)
tensor(\[\[0., 0., 0.\],
        \[0., 0., 0.\]\])

Copy to clipboard

## [Config](https://docs.pytorch.org/docs/stable/notes/serialization.html#id18)[#](https://docs.pytorch.org/docs/stable/notes/serialization.html#module-torch.utils.serialization "Link to this heading")

`torch.utils.serialization.config` provides a global config that can control the behavior of `torch.save` and `torch.load`.

`torch.utils.serialization.config.save` contains options that control the behavior of `torch.save`.

> -   `compute_crc32`: whether to compute and write the zip file checksum (Default : `True`). See [`set_crc32_options()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.set_crc32_options "torch.serialization.set_crc32_options").
> -   `use_pinned_memory_for_d2h`: for storages that are on an accelerator when passed to `torch.save`, whether to move storage to pinned memory or pageable memory on CPU within `torch.save`. (Default: `False` (i.e. pageable))
> -   `storage_alignment`: alignment of storages in the checkpoint during `torch.save` in bytes. (Default `64`)

`torch.utils.serialization.config.load` contains options that control the behavior of `torch.load`.

> -   `mmap`: See the documentation for `mmap` argument in [`torch.load()`](https://docs.pytorch.org/docs/stable/generated/torch.load.html#torch.load "torch.load"). This config will set the behavior of `mmap` for `torch.load` if it is not already explicitly passed to the `torch.load` call (Default : `False`).
> -   `endianness`: See [`set_default_load_endianness()`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.set_default_load_endianness "torch.serialization.set_default_load_endianness"). (Default : `torch.serialization.LoadEndianness.NATIVE`)
> -   `mmap_flags`: See [`set_default_mmap_options`](https://docs.pytorch.org/docs/stable/notes/serialization.html#torch.serialization.set_default_mmap_options "torch.serialization.set_default_mmap_options"). (Default : `MAP_PRIVATE`)
> -   `calculate_storage_offsets`: If this config is set to `True`, offsets for storages will be calculated rather than read via random reads when using `torch.load(mmap=True)`. This minimizes random reads, which can be helpful when the file is being loaded over a network. (Default : `False`)

