// Define an enum for different game actions
enum Action { move, take, open, look }

// Class to simulate game logic
class Game {
  // Store player's current location
  String location = 'start';

  // Process actions taken by the player
  void handleAction(Action action) {
    switch (action) {
      case Action.move:
        location = 'forrest'; // Intentional typo in location name.
        break;
      case Action.take:
        if (location == 'forest') {
          print('You found a hidden treasure!');
        } else {
          print('There is nothing to take here.');
        }
        break;
      case Action.open:
        if (location == 'cabin') {
          print('You opened the cabin door.');
        } else {
          print('There is no cabin here to open.');
        }
        break;
      case Action.look:
        print('You are at $location');
        break;
      default:
        print('Unknown action.');
    }
  }

  // Start the game loop
  void start() {
    print('Game started. You are at the $location.');
    handleAction(Action.move);
    handleAction(Action.look);
    handleAction(Action.take);
  }
}

void main() {
  var game = Game();
  game.start();
}
