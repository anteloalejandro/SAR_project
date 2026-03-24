# SAR Web browser

Project for the SAR (*Information Storage and Retrieval Systems*) course of the Universitat Politècnica de València

## Dev Environment

The python virtual envirnoment is located on [.venv](.venv).
You can either run `.venv/bin/activate` directly or install and set up [`direnv`][direnv].

You can also find a report of the work in this repository (written in spanish) on [informe.typ](documents/informe.typ).
The report is in [typst][typst] format, so the [`typst` compiler][typst-comp] is needed to convert it to PDF.

[direnv]: https://github.com/direnv/direnv?tab=readme-ov-file#getting-started
[typst]: https://typst.app/
[typst-comp]: https://github.com/typst/typst

## Dependencies

The dependencies are listed in the [requirements.txt](requirements.txt) file.

They can be installed using:

```bash
pip install -r requirements.txt
```

## Running

The program is divided into 2 entry points: `SAR_Indexer.py` and `SAR_Searcher.py`.

You can run these directly with `python` or use any of the helper scripts found in [scripts](scripts).
With `direnv` set up, said directory is loaded into the `PATH` envirnoment variable.
