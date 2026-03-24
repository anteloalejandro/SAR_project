#import "@preview/ilm:2.0.0": *

#set text(lang: "es")
#set figure(supplement: "Figura")

#show: ilm.with(
  title: "Buscador Web",
  authors: "Alejandro Antelo Fashoro",
  date: datetime.today(),
  date-format: "[day] / [month] / [year repr:full]",
  raw-text: "use-typst-default",
  table-of-contents: none,
  external-link-circle: false,
  chapter-pagebreak: false,
  footer: "page-number-center",
  paper-size: "a4"
)

= Implementaciones

== Indexación

Toda la lógica de la indexación de documentos recae sobre ```python index_file()```, que es llamado por ```python index_dir()``` para cada documento `.json` que encuentra en la ruta especificada.

Cada documento que procesa ```python index_file()``` debe ser registrado en ```python self.docs```, identificándolo mediante una *ID incremental* única para cada documento: ```python docid = len(self.docs)```.

Los documentos `.json` no son realmente archivos en formato JSON, sino que son colecciones de *objetos JSON separados por un salto de línea*. Estos objetos son los artículos con los que se trabaja, y tienen el siguiente formato

#figure(
  ```json
  {
    "url": "https://es.wikipedia.org/wiki/Ronald_Melzer",
    "title": "Ronald Melzer",
    "summary": " \n \n \n \n \n \n \n \nRonald «Ronny» Melzer (Montevideo...",
    "sections": [
      {
        "name": "Biografía",
        "text": "Nació en Montevideo en una familia de inmigrantes judíos...",
        "subsections": []
      },
      {
        "name": "Referencias",
        "text": "↑ a b El hombre que miraba diferente\n↑ «Ronald Melzer:...",
        "subsections": []
      },
      {
        "name": "Enlaces externos",
        "text": "Único, insoportable, irremplazable. Ronald Melzer (1956...",
        "subsections": []
      }
    ]
  }
  ```,
  caption: "Ejemplo de artículo"
)

Por cada artículo se tiene que generar otra ID incremental con la que identificarlo en el diccionario ```python self.articles```, que tiene como valores un diccionario con el documento al que pertenece (`document`) y su índice dentro de dicho documento (`relative_position`).

Haciendo uso del método ```python parse_article()``` de ```python SAR_Indexer``` se pasan los objetos JSON a un ```python Dict[str,str]``` que tiene, entre otras, la clave `all`, cuyo valor es la *combinación de todas las cadenas de texto* (título, resumen, secciones, etc.) separadas por un salto de línea. Precisamente el valor de la clave `all` es la cadena a tokenizar por defecto.

Para tokenizar la cadena se siguen los siguientes pasos:

+ Se limpia esta única cadena de texto eliminando todos los caracteres no alfanuméricos, exceptuando los delimitadores de términos (espacio, salto de línea y tabulador). Para ello extrae todo lo que encaja con la expresión regular ```re /[\w\s]+/``` y se aúna en una nueva cadena.

+ Tras limpiar la cadena, se pasa a minúscula, y se separa en términos en base a los delimitadores ```re \s+```, obviando los términos vacíos.

+ Para cada uno de los términos del artículo, se actualiza la ```python PostingList``` de su entrada en el índice invertido ```python self.index``` con el artículo en el que se ha encontrado el término. Así, se consigue un índice invertido con el que sacar a qué documentos pertenece cada término.

La ```python PostingList``` se ha definido en una clase aparte para ofrecer una interfaz consistente en caso de que hubiese que cambiar a futuro su estructura interna.

== Similitud semántica

=== Función ```python update_chunks()```

Haciendo uso de la librería `nltk`, se cargan los chunks de `frases.txt`.

= Ampliaciones

== Título de ampliación aquí
