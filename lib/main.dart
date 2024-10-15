import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Магазин товаров',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Product> products = [];
  List<CartItem> cartItems = [];
  String jsonPath = '';

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> getJsonFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/data.json';
  }

  Future<void> loadProducts() async {
    jsonPath = await getJsonFilePath();
    if (File(jsonPath).existsSync()) {
      final String response = await File(jsonPath).readAsString();
      final List<dynamic> data = json.decode(response);
      setState(() {
        products = data.map((json) => Product.fromJson(json)).toList();
      });
      _loadFavorites();
    } else {
      File(jsonPath).writeAsString('[]');
    }
  }

  Future<void> saveProductsToFile() async {
    final file = File(jsonPath);
    final List<Map<String, dynamic>> jsonProducts = products.map((p) => p.toJson()).toList();
    await file.writeAsString(json.encode(jsonProducts));
  }

  Future<void> _loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? favoriteIds = prefs.getStringList('favorites');
    if (favoriteIds != null) {
      setState(() {
        for (var product in products) {
          product.isFavorite = favoriteIds.contains(product.id.toString());
        }
      });
    }
  }

  Future<void> _saveFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favoriteIds = products.where((product) => product.isFavorite).map((product) => product.id.toString()).toList();
    prefs.setStringList('favorites', favoriteIds);
  }

  void _toggleFavorite(Product product) {
    setState(() {
      product.isFavorite = !product.isFavorite;
      _saveFavorites();
      saveProductsToFile(); // Save changes after toggling
    });
  }

  void _addProduct(Product product) {
    setState(() {
      products.add(product);
      saveProductsToFile();
    });
  }

  void _deleteProduct(Product product) {
    setState(() {
      products.remove(product);
      saveProductsToFile(); // Save changes after deletion
    });
  }

  void _addToCart(Product product) {
    setState(() {
      // Проверяем, существует ли уже товар в корзине
      CartItem? existingItem = cartItems.firstWhere(
            (item) => item.product.id == product.id,
        orElse: () => CartItem(product: product, quantity: 0), // Возвращаем новый CartItem с количеством 0
      );

      if (existingItem.quantity > 0) {
        // Если товар уже в корзине, увеличиваем его количество
        existingItem.quantity++;
      } else {
        // Если товара нет в корзине, добавляем его с количеством 1
        cartItems.add(CartItem(product: product, quantity: 1));
      }
    });
  }





  void _removeFromCart(BuildContext context, CartItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Удалить товар?"),
          content: Text("Вы действительно хотите удалить ${item.product.name} из корзины?"),
          actions: [
            TextButton(
              child: Text("Отмена"),
              onPressed: () {
                Navigator.of(context).pop(); // Закрыть диалог без удаления
              },
            ),
            TextButton(
              child: Text("Удалить"),
              onPressed: () {
                _deleteCartItem(item); // Call the method to delete the item
                Navigator.of(context).pop(); // Закрыть диалог
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${item.product.name} удален из корзины")),
                );
              },
            ),
          ],
        );
      },
    );
  }



  void _increaseQuantity(CartItem item) {
    setState(() {
      item.quantity++;
    });
  }
  void _deleteCartItem(CartItem item) {
    setState(() {
      cartItems.remove(item);
      saveProductsToFile(); // Optionally save changes if needed
    });
  }
  void _decreaseQuantity(CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _removeFromCart(context,item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _pages = [
      ProductListPage(
        onFavoriteToggle: _toggleFavorite,
        products: products,
        onDelete: _deleteProduct,
        onAddToCart: _addToCart,
      ),
      FavoritePage(
        favorites: products.where((product) => product.isFavorite).toList(),
        onFavoriteToggle: _toggleFavorite,
      ),
      CartPage(
        cartItems: cartItems,
        onRemove: _removeFromCart,
        onIncrease: _increaseQuantity,
        onDecrease: _decreaseQuantity,
      ),
      ProfilePage(),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Избранное',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Корзина',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue, // Цвет активной иконки
        unselectedItemColor: Colors.grey, // Цвет неактивной иконки
        onTap: _onItemTapped,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProductPage(
                onProductAdded: _addProduct,
                nextId: products.isNotEmpty ? products.last.id + 1 : 1,
              ),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class Product {
  final int id;
  final String name;
  final String description;
  final String image;
  bool isFavorite;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    this.isFavorite = false,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      image: json['image'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'isFavorite': isFavorite,
    };
  }

  @override
  bool operator ==(other) {
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class ProductListPage extends StatelessWidget {
  final Function(Product) onFavoriteToggle;
  final List<Product> products;
  final Function(Product) onDelete;
  final Function(Product) onAddToCart;

  ProductListPage({required this.onFavoriteToggle, required this.products, required this.onDelete, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Список товаров'),
      ),
      body: products.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: (MediaQuery.of(context).size.width / 5) / (MediaQuery.of(context).size.height / 8),
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailPage(
                      product: product,
                      onDelete: () => onDelete(product),
                      onFavoriteToggle: onFavoriteToggle,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            product.image,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(product.name),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                product.isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: product.isFavorite ? Colors.red : null,
                              ),
                              onPressed: () => onFavoriteToggle(product),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_shopping_cart),
                              onPressed: () => onAddToCart(product),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class FavoritePage extends StatelessWidget {
  final List<Product> favorites;
  final Function(Product) onFavoriteToggle;

  FavoritePage({required this.favorites, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Избранные товары'),
      ),
      body: favorites.isEmpty
          ? Center(child: Text('Нет избранных товаров'))
          : GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Количество столбцов в сетке
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: (MediaQuery.of(context).size.width / 5) / (MediaQuery.of(context).size.height / 8),
        ),
        itemCount: favorites.length,
        itemBuilder: (context, index) {
          final product = favorites[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailPage(
                    product: product,
                    onDelete: () {}, // Вы можете добавить функционал удаления, если необходимо
                    onFavoriteToggle: onFavoriteToggle,
                  ),
                ),
              );
            },
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(
                          product.image,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(product.name),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              product.isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: product.isFavorite ? Colors.red : null,
                            ),
                            onPressed: () => onFavoriteToggle(product),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CartPage extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(BuildContext, CartItem) onRemove; // Update to include BuildContext
  final Function(CartItem) onIncrease;
  final Function(CartItem) onDecrease;

  CartPage({
    required this.cartItems,
    required this.onRemove,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Корзина'),
      ),
      body: cartItems.isEmpty
          ? Center(child: Text('Корзина пуста'))
          : GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Количество столбцов
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: (MediaQuery.of(context).size.width / 2) / 250,
        ),
        itemCount: cartItems.length,
        itemBuilder: (context, index) {
          final cartItem = cartItems[index];
          return Dismissible(
              key: Key(cartItem.product.id.toString()),
            onDismissed: (direction) {
              onRemove(context, cartItem); // Call onRemove with context and cartItem
            },
            background: Container(color: Colors.red),
          child: Card(
          elevation: 3,
          child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Image.asset(
                      cartItem.product.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(cartItem.product.name, textAlign: TextAlign.center),
                        Text("Количество: ${cartItem.quantity}"),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () => onDecrease(cartItem),
                      ),
                      Text('${cartItem.quantity}'),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () => onIncrease(cartItem),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

        },
      ),
    );
  }
}

class ProductDetailPage extends StatelessWidget {
  final Product product;
  final Function onDelete;
  final Function(Product) onFavoriteToggle;

  ProductDetailPage({required this.product, required this.onDelete, required this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: Column(
        children: [
          Image.asset(product.image),
          SizedBox(height: 20),
          Text(product.description),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => onFavoriteToggle(product),
            child: Text(product.isFavorite ? 'Убрать из избранного' : 'Добавить в избранное'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => onDelete(),
            child: Text('Удалить товар'),
          ),
        ],
      ),
    );
  }
}

class AddProductPage extends StatelessWidget {
  final Function(Product) onProductAdded;
  final int nextId;

  AddProductPage({required this.onProductAdded, required this.nextId});

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить товар'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Название товара'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Описание товара'),
            ),
            TextField(
              controller: _imageController,
              decoration: InputDecoration(labelText: 'Путь к изображению'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final newProduct = Product(
                  id: nextId,
                  name: _nameController.text,
                  description: _descriptionController.text,
                  image: _imageController.text,
                );
                onProductAdded(newProduct);
                Navigator.pop(context);
              },
              child: Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String surname = '';
  String firstName = '';
  String patronymic = '';
  String email = '';
  String phone = '';

  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _patronymicController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      surname = prefs.getString('surname') ?? '';
      firstName = prefs.getString('firstName') ?? '';
      patronymic = prefs.getString('patronymic') ?? '';
      email = prefs.getString('email') ?? '';
      phone = prefs.getString('phone') ?? '';
      _surnameController.text = surname;
      _firstNameController.text = firstName;
      _patronymicController.text = patronymic;
      _emailController.text = email;
      _phoneController.text = phone;
    });
  }

  Future<void> _saveProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('surname', _surnameController.text);
    prefs.setString('firstName', _firstNameController.text);
    prefs.setString('patronymic', _patronymicController.text);
    prefs.setString('email', _emailController.text);
    prefs.setString('phone', _phoneController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _surnameController,
              decoration: InputDecoration(labelText: 'Фамилия'),
            ),
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: 'Имя'),
            ),
            TextField(
              controller: _patronymicController,
              decoration: InputDecoration(labelText: 'Отчество'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Электронная почта'),
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Телефон'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _saveProfile();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Данные профиля сохранены')),
                );
              },
              child: Text('Сохранить изменения'),
            ),
          ],
        ),
      ),
    );
  }
}
