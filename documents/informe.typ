#import "@preview/ilm:2.0.0": *
#import "@preview/calloutly:1.0.0" : callout-style, callout, note, tip, important, warning, caution

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

#show: callout-style.with(style: "quarto")

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

Para procesar la cadena se siguen los siguientes pasos:

+ Se limpia y tokeniza la cadena usando ```python self.tokenize()```, lo que resulta en una lista de términos.

+ Para cada uno de los términos del artículo, se actualiza la ```python PostingList``` de su entrada en el índice invertido ```python self.index``` con el artículo en el que se ha encontrado el término. Así, se consigue un índice invertido con el que sacar a qué artículos pertenece cada término.

=== La clase `PostingList`

La ```python PostingList``` se ha definido en una clase aparte para ofrecer una interfaz consistente en caso de que hubiese que cambiar a futuro su estructura interna.

Esta clase está formada por una variable `postings` de tipo ```python Dict[int, list[int]]```, donde las claves del diccionario son los _posting_ (en este caso, `artid`) y su valor asociado es una lista de las posiciones en las que aparece el término en el artículo. Según si se hace un índice posicional o no, se rellena la lista o se deja vacía al indexar.

#callout(type: "note", title: "Beneficios del diccionario")[
  Usar un diccionario de esta forma también ahorra tener que comprobar documentos repetidos.
]

También se han sobrecargado algunos operadores para trabajar de forma más tersa y natural con operaciones comunes como el `A AND B`, que pasa a ser ```python A & B``` o `A NOT AND B`, que pasa a ser ```python A - B```.

Cabe destacar que para este tipo de operaciones carece de sentido conservar las posiciones en el resultado, así que siempre se dejan las listas vacías. Del mismo modo, resulta conveniente poder obtener una `PostingList` con la que operar a partir de una lista de `artid`, así que el constructor permite pasar una lista a partir de la cuál crearla.

== Recuperación

Para recuperar documentos relevantes a una consulta primero es necesario diferenciar entre las consultas normales con múltiples términos, como `recuperación de la información`, y las búsquedas posicionales, como `"recuperación de la información"`. Como simplemente dividir la consulta en palabras divididas por espacios no es suficiente, se ha creado una función ```python parse_query()``` que devuelve una lista con las partes que conforman la consulta (consultas normales, `NOT`, y consultas posicionales), debidamente separadas.

Una vez tratada la consulta, se debe diferenciar entre las 3 operaciones que pueden darse:

+ *Negación `NOT`.* Sólo se da cuando hay un `NOT` al principio de la consulta. En este punto no tenemos otros nodos con los que comparar, así que se forma una `PostingList` con todos los términos del índice inverso y se le resta la `PostingList` formada por el término siguiente al `NOT`.

+ *Intersección `AND`.* Se da cuándo se separan dos partes de la consulta mediante espacio en blanco. En este caso se guarda el resultado de la operación `&` entre las `PostingList`.

+ *Diferencia `NOT AND`.* Se ha de calcular cuando los términos se separan por un `NOT`. De forma similar a la intersección, se guarda el resultado de la operación `|`.

= Ampliaciones

== Similitud semántica

=== Función ```python update_chunks()```

Haciendo uso de la librería `nltk`, se cargan los chunks de `frases.txt`.
