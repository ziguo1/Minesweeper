final int ROWS = 25, COLS = 25, PADDING = 30;
final int MINE_COUNT = (ROWS * COLS) / 8;

ArrayList<Button> butts = new ArrayList(), activeButts = new ArrayList(), hoverButts = new ArrayList();
Square[][] squares;
int mineSizeX, mineSizeY;
boolean hasStarted = false, bombDetonated = false, won = false, debug = false, triggerCheck = false;

void setup() {
  size(512, 512);
  mineSizeX = (width - 2 * PADDING) / COLS;
  mineSizeY = (height - 2 * PADDING) / ROWS;
  frameRate(24);
  reset();
}

long hintDebounce = System.currentTimeMillis();
void draw() {
  background(color(192));
  handleButtons();
  lastState = mousePressed;
  //if (bombDetonated) return;

  if ((key == 'h' || key == 'r' || key == 'd' || key == 'f') && keyPressed && System.currentTimeMillis() - hintDebounce > 300) {
    if (key == 'h') {
      if (hoverButts.size() > 0) {
        Square hover = (Square) hoverButts.get(0);
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            int row = hover.getPose()[0] + (i - 1), col = hover.getPose()[1] + (j - 1);
            if (row < 0 || col < 0 || row >= squares.length || col >= squares[row].length) continue;
            Square sq = squares[row][col];
            if (sq != null && (sq.type == SquareType.BOMB_FLAGGED || sq.type == SquareType.BOMB)) {
              sq.type = SquareType.DEBUGGED;
              sq.found = true;
            }
          }
        }
      }
    } else if (key == 'r') {
      reset();
      hintDebounce = System.currentTimeMillis();
      return;
    } else if (key == 'd') {
      debug = !debug;
    } else if (key == 'f' && hoverButts.size() > 0) {
      Square sq = (Square) hoverButts.get(0);
      sq.flag();
    }
    hintDebounce = System.currentTimeMillis();
  }
  if (drawModalCheck()) return;
  if (!hasStarted && mousePressed && activeButts.size() > 0) {
    Square sq = (Square) activeButts.get(0);
    fillMap(sq.getPose()[0], sq.getPose()[1]);
    hasStarted = true;
  }
  for (Square[] row : squares) {
    for (Square sq : row)
      sq.tick();
  }
}

boolean drawModalCheck() {
  if (!hasStarted) return false;
  if (bombDetonated) {
    int bombCnt = 0;
    for (Square[] row : squares) {
      for (Square sq : row) {
        if (sq.type == SquareType.BOMB || sq.type == SquareType.BOMB_FLAGGED) bombCnt++;
      }
    }
    drawModal(bombCnt);
    return true;
  } else {
    if (!won) {
      if (!triggerCheck) return false;
      triggerCheck = false;
      for (Square[] row : squares) {
        for (Square sq : row) {
          if (sq.type == SquareType.BOMB || sq.type == SquareType.SAFE_FLAGGED) return false;
        }
      }
      won = true;
    }
    drawModal(0);
    return true;
  }
}

void drawModal(int totalBombs) {
  String text = (bombDetonated ? String.format("Game Over! You accidentally touched a bomb (%d total)!", totalBombs) : "You win!")
    + " Press 'r' to reset.";
  push();
  fill(color(0));
  textSize(16);
  textAlign(CENTER, CENTER);
  text(text, width / 2, (PADDING / 2));
  pop();
}

void reset() {
  butts = new ArrayList();
  activeButts = new ArrayList();
  hoverButts = new ArrayList();
  squares = new Square[ROWS][];
  hasStarted = false;
  bombDetonated = false;
  won = false;
  triggerCheck = true;
  for (int i = 0; i < squares.length; i++) {
    squares[i] = new Square[COLS];
    for (int j = 0; j < squares[i].length; j++) {
      squares[i][j] = new Square(i, j, SquareType.SAFE);
    }
  }
}

void fillMap(int plottedX, int plottedY) {
  int plottedCount = 0;
  while (plottedCount < MINE_COUNT) {
    int row = (int) (Math.random() * ROWS), col = (int) (Math.random() * COLS);
    if (row == plottedY && col == plottedX) continue;
    squares[row][col].setType(SquareType.BOMB);
    plottedCount++;
  }
}

// Guido is for the weak
public enum ButtonState {
  IDLE, HOVER, ACTIVE;
}

public enum SquareType {
  SAFE, BOMB, BOMB_FLAGGED, SAFE_FLAGGED, DEBUGGED;
}

public class Square extends Button {
  protected SquareType type;
  protected boolean found;
  protected int poseX, poseY;
  protected String displ;

  public Square(int poseX, int poseY, SquareType type) {
    super(PADDING + (poseX * mineSizeX), PADDING + (poseY * mineSizeY), mineSizeX, mineSizeY);
    this.poseX = poseX;
    this.poseY = poseY;
    this.type = type;
    this.found = false;
    this.displ = null;
  }

  public SquareType getType() {
    return type;
  }
  public void setType(SquareType type) {
    this.type = type;
  }
  public int[] getPose() {
    return new int[] { poseX, poseY };
  }

  public void draw() {
    push();
    if (type == SquareType.BOMB && (bombDetonated || won || debug)) {
      fill(color(255, 0, 0));
    } else if (!found && type != SquareType.BOMB_FLAGGED && type != SquareType.SAFE_FLAGGED) {
      fill(state == ButtonState.HOVER ? color(164) : (state == ButtonState.ACTIVE ? color(173) : color(128)));
    } else {
      switch(type) {
      case SAFE:
        fill(color(192));
        break;
      case BOMB:
        fill(color(255, 0, 0));
        break;
      case SAFE_FLAGGED:
      case BOMB_FLAGGED:
        fill(color(255, 255, 0));
        break;
      case DEBUGGED:
        fill(color(0, 0, 255));
        break;
      }
    }
    rect(x, y, w, h);

    if (displ != null) {
      textSize(8);
      fill(color(0));
      text(displ, x + (w / 2), y + ((h + 8) / 2));
    }
    pop();
  }

  public void propagate() {
    propagate(new ArrayList());
  }

  public void propagate(ArrayList<Square> propagated) {
    if (type == SquareType.BOMB || type == SquareType.BOMB_FLAGGED) return;
    triggerCheck = true;
    int mineCount = 0;
    this.found = true;

    ArrayList<Square> neighbors = new ArrayList();
    for (int i = 0; i < 3; i++) {
      int row = poseX + (i - 1);
      if (row < 0 || row >= squares.length) break;
      for (int j = 0; j < 3; j++) {
        int col = poseY + (j - 1);
        Square[] dumbassRow = squares[row];
        if (col < 0 || col >= dumbassRow.length || dumbassRow[col] == this) continue;
        Square sq = dumbassRow[col];
        if (sq.type == SquareType.BOMB || sq.type == SquareType.BOMB_FLAGGED)
          mineCount++;
        if (propagated.contains(sq)) continue;
        propagated.add(sq);
        neighbors.add(sq);
      }
    }


    if (mineCount == 0) {
      for (Square sq : neighbors) {
        sq.propagate(propagated);
      }
    } else {
      this.displ = "" + mineCount;
    }
  }

  public void flag() {
    triggerCheck = true;
    if (type == SquareType.BOMB) {
      this.type = SquareType.BOMB_FLAGGED;
    } else if (type == SquareType.SAFE) {
      this.type = SquareType.SAFE_FLAGGED;
    } else if (type == SquareType.BOMB_FLAGGED) {
      this.type = SquareType.BOMB;
    } else if (type == SquareType.SAFE_FLAGGED) {
      this.type = SquareType.SAFE;
    }
  }

  public void tick() {
    if (bombDetonated || !mousePressed || this.state != ButtonState.ACTIVE || found) return;
    if (type == SquareType.BOMB) {
      if (mouseButton == LEFT) {
        bombDetonated = true;
        this.found = true;
        return;
      } else if (mouseButton == RIGHT) {
        this.type = SquareType.BOMB_FLAGGED;
      }
      return;
    } else if (type == SquareType.BOMB_FLAGGED) {
      if (mouseButton == RIGHT) {
        this.type = SquareType.BOMB;
      }
    } else if (type == SquareType.SAFE_FLAGGED) {
      if (mouseButton == RIGHT) {
        this.type = SquareType.SAFE;
      }
    } else if (type == SquareType.SAFE && !found) {
      if (mouseButton == LEFT) {
        // set off neighbors
        this.found = true;
        propagate();
      } else if (mouseButton == RIGHT) {
        this.type = SquareType.SAFE_FLAGGED;
      }
    }
  }
}

public class Button {
  protected int x, y, w, h;
  protected ButtonState state;

  public Button(int x, int y, int w, int h) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.state = ButtonState.IDLE;
    butts.add(this);
  }

  public ButtonState getState() {
    return state;
  }
  public int getX() {
    return x;
  }
  public int getY() {
    return y;
  }
  public int getWidth() {
    return w;
  }
  public int getHeight() {
    return h;
  }
  public void setX(int x) {
    this.x = x;
  }
  public void setY(int y) {
    this.y = y;
  }
  public void setWidth(int w) {
    this.w = w;
  }
  public void setHeight(int h) {
    this.h = h;
  }

  public void draw() {
    switch(state) {
    default:
      push();
      fill(color(96));
      rect(x, y, w, h);
      pop();
      break;
    case HOVER:
      push();
      fill(color(128));
      rect(x, y, w, h);
      pop();
      break;
    case ACTIVE:
      push();
      fill(color(224));
      rect(x, y, w, h);
      pop();
      break;
    }
  }

  public void hook() {
    butts.add(this);
  }

  public void unhook() {
    butts.remove(this);
  }
}

boolean lastState = false;
void handleButtons() {
  for (Button butt : butts) {
    if (mouseX > butt.x && mouseX < (butt.x + butt.w) && mouseY > butt.y && mouseY < (butt.y + butt.h)) {
      if (mousePressed) {
        if (lastState == true) continue;
        butt.state = ButtonState.ACTIVE;
        if (!activeButts.contains(butt)) activeButts.add(butt);
      } else {
        butt.state = ButtonState.HOVER;
        if (!hoverButts.contains(butt)) hoverButts.add(butt);
      }
    } else {
      butt.state = ButtonState.IDLE;
      activeButts.remove(butt);
      hoverButts.remove(butt);
    }
    butt.draw();
  }
}

// 'r' resets the game
// 'h' highlights and removes all bombs in a 3 unit long square of the hovered square
// 'd' toggles debug mode (show all mines)
// 'f' or rmb flags the hovered square
// lmb reveals the squared