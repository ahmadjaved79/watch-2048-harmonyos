import preferences from '@ohos.data.preferences'
import vibrator from '@ohos.vibrator'



interface MergeResult {
  result: number[]
  moved: boolean
}

@Entry
@Component
struct Index {
  @State grid: number[] = [0,0,0,0,0,0,0,0,0]
  @State score: number = 0
  @State gameOver: boolean = false
  @State bestScore: number = 0
  private pref: preferences.Preferences | undefined = undefined


  aboutToAppear() {
    try {
      preferences.getPreferences(getContext(this), 'game2048')
        .then(p => {
          this.pref = p

          // Load best score
          this.bestScore = p.getSync('bestScore', 0) as number

          // Load saved game
          let savedGrid = p.getSync('grid', '') as string
          let savedScore = p.getSync('score', 0) as number

          if (savedGrid) {
            this.grid = JSON.parse(savedGrid)
            this.score = savedScore
          } else {
            // Fresh game
            this.spawn()
            this.spawn()
          }
        })
    } catch (e) {
      console.error('Load failed', e)
      this.spawn()
      this.spawn()
    }

  }

  // ---------- GAME CORE ----------


  spawn() {
    let empty: number[] = []
    this.grid.forEach((v, i) => {
      if (v === 0) empty.push(i)
    })

    if (empty.length === 0) return
    let idx = empty[Math.floor(Math.random() * empty.length)]
    this.grid[idx] = Math.random() < 0.9 ? 2 : 4
  }


  saveGame() {
    if (!this.pref) return
    try {
      this.pref.putSync('grid', JSON.stringify(this.grid))
      this.pref.putSync('score', this.score)
      this.pref.flush()
    } catch (e) {
      console.error('Save game failed', e)
    }
  }

  mergeLine(line: number[]): MergeResult {
    let original = [...line]
    let arr = line.filter(v => v !== 0)

    for (let i = 0; i < arr.length - 1; i++) {
      if (arr[i] === arr[i + 1]) {
        arr[i] *= 2
        this.score += arr[i]
        arr[i + 1] = 0
      }
    }

    arr = arr.filter(v => v !== 0)
    while (arr.length < 3) arr.push(0)

    let moved = arr.some((v, i) => v !== original[i])
    if (this.score > this.bestScore) {
      this.bestScore = this.score
      try {
        this.pref?.putSync('bestScore', this.bestScore)
        this.pref?.flush()
      } catch (e) {
        console.error('Best score save failed', e)
      }
    }



    return { result: arr, moved }
  }

  moveLeft() {
    let moved = false
    for (let r = 0; r < 3; r++) {
      let row = this.grid.slice(r * 3, r * 3 + 3)
      let res = this.mergeLine(row)
      for (let c = 0; c < 3; c++) {
        this.grid[r * 3 + c] = res.result[c]
      }
      if (res.moved) moved = true
    }
    if (moved) {
      this.spawn()
    }
    this.checkGameOver()
    this.saveGame()

  }

  moveRight() {
    let moved = false
    for (let r = 0; r < 3; r++) {
      let row = this.grid.slice(r * 3, r * 3 + 3).reverse()
      let res = this.mergeLine(row)
      res.result.reverse().forEach((v, c) => {
        this.grid[r * 3 + c] = v
      })
      if (res.moved) moved = true
    }
    if (moved) {
      this.spawn()
    }
    this.checkGameOver()
    this.saveGame()

  }

  moveUp() {
    let moved = false
    for (let c = 0; c < 3; c++) {
      let col = [this.grid[c], this.grid[c+3], this.grid[c+6]]
      let res = this.mergeLine(col)
      for (let r = 0; r < 3; r++) {
        this.grid[r * 3 + c] = res.result[r]
      }
      if (res.moved) moved = true
    }
    if (moved) {
      this.spawn()
    }
    this.checkGameOver()
    this.saveGame()

  }

  moveDown() {
    let moved = false
    for (let c = 0; c < 3; c++) {
      let col = [this.grid[c], this.grid[c+3], this.grid[c+6]].reverse()
      let res = this.mergeLine(col)
      res.result.reverse().forEach((v, r) => {
        this.grid[r * 3 + c] = v
      })
      if (res.moved) moved = true
    }
    if (moved) {
      this.spawn()
    }
    this.checkGameOver()
    this.saveGame()

  }

  checkGameOver() {
    if (this.hasAnyMove()) return

    // 🔥 Force ArkUI state refresh
    this.grid = [...this.grid]
    this.gameOver = true
    if (!this.gameOver) return
    try {
      vibrator.vibrate(100)
    } catch (e) {
      console.error(e)
    }



  }


  hasAnyMove(): boolean {
    // empty cell exists
    if (this.grid.includes(0)) return true

    // horizontal & vertical merge check
    for (let r = 0; r < 3; r++) {
      for (let c = 0; c < 3; c++) {
        let i = r * 3 + c
        if (c < 2 && this.grid[i] === this.grid[i + 1]) return true
        if (r < 2 && this.grid[i] === this.grid[i + 3]) return true
      }
    }
    return false
  }


  restartGame() {
    this.grid = [0,0,0,0,0,0,0,0,0]
    this.score = 0
    this.gameOver = false

    if (this.pref) {
      try {
        this.pref.deleteSync('grid')
        this.pref.deleteSync('score')
        this.pref.flush()
      } catch (e) {
        console.error('Clear failed', e)
      }
    }

    this.spawn()
    this.spawn()
  }



  // ---------- UI ----------

  build() {
    Stack() {
      // ================= MAIN GAME UI =================
      Column() {
        Blank().height(24)

        // SCORE
        Row() {
          Text('SCORE')
            .fontSize(12)
            .fontColor('#AAAAAA')

          Text(this.score.toString())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 6 })

          Text(`BEST ${this.bestScore}`)
            .fontSize(18)
            .fontColor('#AAAA')
            .margin({left:3})

        }
        .padding(12)
        .backgroundColor('#1E1E1E')
        .borderRadius(20)
        .margin({ bottom: 18 })

        // GRID
        Grid() {
          ForEach(this.grid, (value: number) => {
            GridItem() {
              Text(value === 0 ? '' : value.toString())
                .fontSize(25)
                .fontWeight(FontWeight.Bold)
                .textAlign(TextAlign.Center)
                .width('100%')
                .height('100%')
                .backgroundColor(value === 0 ? '#2A2A2A' : '#F5B301')
                .borderRadius(16)
            }
            .padding(3)
          })
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsTemplate('1fr 1fr 1fr')
        .width(130)
        .height(130)
        .borderRadius(15)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      // ================= GAME OVER OVERLAY =================
      if (this.gameOver) {
        Column() {
          Text('GAME OVER')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ bottom: 8 })

          Text('Swipe to restart')
            .fontSize(12)
            .fontColor('#CCCCCC')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.75)')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .gesture(
      SwipeGesture()
        .onAction((event) => {
          if (this.gameOver) {
            this.restartGame()
            return
          }

          let angle = event.angle
          if (angle > 135 || angle < -135) this.moveLeft()
          else if (angle > -45 && angle < 45) this.moveRight()
          else if (angle >= 45 && angle <= 135) this.moveUp()
          else if (angle <= -45 && angle >= -135) this.moveDown()
        })
    )
  }

}