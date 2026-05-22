#import "@preview/ilm:2.0.0": *
#import "@preview/calloutly:1.0.0": callout, callout-style, caution, important, note, tip, warning

#set text(lang: "es")
#set figure(supplement: "Figura")

#show: ilm.with(
  title: "Buscador Web",
  authors: "Alejandro Antelo Fashoro",
  date: datetime.today(),
  date-format: "[day] / [month] / [year repr:full]",
  raw-text: "use-typst-default",
  table-of-contents: outline(title: "Índice"),
  external-link-circle: false,
  chapter-pagebreak: false,
  footer: "page-number-center",
  paper-size: "a4",
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
  caption: "Ejemplo de artículo",
)

Por cada artículo se tiene que generar otra ID incremental con la que identificarlo en el diccionario ```python self.articles```, que tiene como valores un diccionario con el documento al que pertenece (`document`) y su índice dentro de dicho documento (`relative_position`).

Haciendo uso del método ```python parse_article()``` de `SAR_Indexer` se pasan los objetos JSON a un ```python Dict[str,str]``` que tiene, entre otras, la clave `all`, cuyo valor es la *combinación de todas las cadenas de texto* (título, resumen, secciones, etc.) separadas por un salto de línea. Precisamente el valor de la clave `all` es la cadena a tokenizar por defecto.

Para procesar la cadena se siguen los siguientes pasos:

+ Se limpia y tokeniza la cadena usando ```python self.tokenize()```, lo que resulta en una lista de términos.

+ Para cada uno de los términos del artículo, se actualiza la ```python PostingList``` de su entrada en el índice invertido ```python self.index``` con el artículo en el que se ha encontrado el término. Así, se consigue un índice invertido con el que sacar a qué artículos pertenece cada término.

=== La clase `PostingList`

La `PostingList` se ha definido en una clase aparte para ofrecer una interfaz consistente en caso de que hubiese que cambiar a futuro su estructura interna.

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

+ *Diferencia `NOT AND`.* Se ha de calcular cuando los términos se separan por un `NOT`. De forma similar a la intersección, se guarda el resultado de la operación `-`.

La recuperación de documentos relevantes, por tanto, se divide en dos pasos.

Primero, se coge el primer término, `first`, y se crea una `PostingList` a partir de él. Si `first` es `NOT`, se sacará la negación del siguiente término.

```python
if first == "NOT":
    excluded = next(queries)
    excluded_posting = self.get_posting(excluded).get_list()
    posting_list_acc = self.reverse_posting(excluded_posting)
else:
    posting_list_acc = self.get_posting(first)
```

La `PostingList` se irá actualizando aplicando la intersección o diferencia con cada uno de los términos siguientes conforme corresponda.

```python
for q in queries:
    if q == "NOT":
        q = next(queries)
        posting_list_acc -= self.get_posting(q)
    else:
        posting_list_acc &= self.get_posting(q)

articles = posting_list_acc.get_list()
```

=== Búsqueda posicional

Cuando no se hace la búsqueda posicional, obtener la `PostingList` correspondiente a un término es trivial, sólo hay que indexar con el término en el índice inverso que se ha creado durante la fase de indexación.

```python
posting_list = self.index[term]
```

No se puede hacer lo mismo con las búsquedas posicionales, que consisten en comprobar las `PostingList` en las que hay una secuencia de términos y, por tanto, no están indexadas en ningún sitio. En su lugar, se tienen que calcular en tiempo de ejecución.

Para simplificar la búsqueda de términos se juntan ambas posibilidades (búsqueda de un sólo término o búsqueda de posicional) en una sola función ```python get_posting()```, que comprueba de antemano cuántos términos hay en la consulta.

```python
if len(term.split()) > 1:
    return self.get_positionals(term)
else:
    return self.index[term] if term in self.index else PostingList()
```

Aquí, el método ```python get_positionals()``` coge un _string_ con términos separados por espacios e itera por ellos, siguiendo estos pasos:

- Por cada término en la búsqueda, coge todos los `artid` en su `PostingList` que coinciden con los de la `PostingList` del término anterior.

- Por cada artículo que coincide coge aquellas posiciones que son exactamente 1 mayores que alguno de las posiciones la iteración anterior.

= Ampliaciones

== Similitud semántica

La búsqueda por similitud semántica consiste en obtener los artículos más relevantes para una _query_ en base la representación vectorial (o _embeddings_) de ambos: Cuanto más cerca está la _query_ de un documento, más importante es dicho documento.

Consiste, por tanto, en dos pasos: La *creación de los _embeddings_* y la *resolución de la propia consulta*.

=== Creación de _embeddings_

En el método `update_chuncks`, haciendo uso de la función ```python nltk.sent_tokenize()```, se cargan los _chunks_ de cada uno de los artículos. Esto se hace una vez para cada artículo.

Los _chunks_ de todos los artículos se guardan en orden en la lista ```python self.chuncks``` dentro de la clase `Sar_Indexer`, y por cada _chunk_ guardado se guarda su `artid` de origen en otra lista, ```python self.chunck_index```. Esta última lista *se usará después para sacar a qué artículo corresponde cada _chunk_*.

Tras procesar todos los artículos, se llama a la función ```python self.create_kdtree()```. Esta función crea un modelo semántico con la función ```python create_semantic_model()```, incluida en el archivo `SAR_lib.py`, que permite crear el modelo semántico especificado en la variable global `SEMANTIC_MODEL` haciendo uso de los métodos en `SAR_semantics.py`.

El modelo semántico se debe ajustar con los datos de entrenamiento, que son los _chunks_ que se han guardado previamente. El ajuste actualiza los atributos `kdtree` y `embeddings` *del modelo*, que se guardan *manualmente* también como atributos de `SAR_Indexer` para usarlos más tarde, durante la búsqueda.

=== Resolución semántica de consultas

En ```python self.solve_query()```, cuando se detecta que el argumento `semantic_threshold` está puesto, se asume que la consulta es semántica, por lo que directamente se devuelve el resultado de ```python self.solve_semantic_query()```.

Esta última función carga el modelo semántico, le vuelve a establecer los atributos `kdtree` y `embeddings` que se habían quedado guardados en `SAR_Indexer`, calculan cuántos documentos tienen una cercanía con la consulta mayor que la especificada por `semantic_threshold`.

El modelo semántico tiene un método ```python query(query, top_k)``` que devuevle el índice de los _chunks_ (junto a sus distancias) más cercanos a `query`.

Para la resolución de la consulta se empieza con ```python top_k = 1```, que irá incrementando hasta que el último resultado (y por tanto, el más lejano) supere el `semantic_threshold`. Una vez suceda esto, y habiendo exluído a este último resultado, tenemos una lista de índices de _chunks_, que se pueden convertir en una lista de `artid` usándolos como índice de `self.chunck_index`.

```python
[
  self.chuck_index[i]
  # indexed_distances es el resultado de self.model.query(), quitando el último elemento
  for _, i in indexed_distances
]
```

Sin embargo, con eso se consigue una lista de con `artid` repetidos, y usar un `set` quitaría las repeticiones pero cambiaría el orden. Se ha solucionado escribiendo una función ```python unique_in_order(self, input, included_in)``` que elimina repeticiones y mantiene el orden de los elementos.

```python
def unique_in_order(self, input, included_in = None):
    result = []
    memo = set()

    for item in input:
        if item in memo or (
            included_in is not None
            and item not in included_in
        ): continue

        memo.add(item)
        result.append(item)

    return result
```

Por tanto, el resultado de la búsqueda semántica, una vez encontrados todos los elementos que no superan el `semantic_threshold`, es:

```python
return self.unique_in_order(
  [self.chunck_index[i] for _, i in indexed_distances]
)
```

== _Reranking_ semántico de consultas

El _reranking_ consiste en coger los resultados de una consulta y reordenarlos para mostrar primero los más relevantes.

En concreto, se procesará la consulta usando `PostingList` y el modelo semántico sólo se usará para reordenar los resultados.

Al igual que en la búsqueda semántica, el primer paso es cargar el modelo semántico y reestablecer sus atributos `kdtree` y `embeddings`.

La diferencia es que en este caso, lo que queremos es usar ```python self.model.query(query, top_k)``` para obtener los índices ordenados *hasta que salgan todos los índices de la búsqueda por `PostingList`*.

En vez de ir de uno en uno, se cogen hasta ```python top_k = self.MAX_EMBEDDINGS``` _embeddings_, se calcula la lista de artículos con `unique_in_order` y se comprueba que no falte ninguno. Si faltasen artículos, se duplica el valor de `top_k` y se repite el proceso.

Finalmente, se filtra la lista con ```python unique_in_order(retrieved_articles, articles)``` eliminar los repetidos, donde el segundo argumento sirve para *filtrar* dejando sólo los que aparecen en él.

El resultado es, entonces, los mismos artículos que la búsqueda con `PostingList`, pero ordenador por relevancia.
