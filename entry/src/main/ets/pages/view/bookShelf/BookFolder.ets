import BookOverlay from '../../../componets/bookDetail/BookOverlay'
import BookGroupsDao from '../../../database/dao/BookGroupsDao'
import { BookGroups } from '../../../database/entities/BookGroups'
import BookManageDialog from './components/dialog/BookManageDialog'
import FolderInfoDialog from './components/dialog/FolderInfoDialog'
import { BookCoverLogic } from '../../../common/utils/BookCoverLogic'
import { AdaptiveLayout } from '../../../common/utils/AdaptiveLayout'

/**
 * 文件夹
 */
@Component
export default struct BookFolder {
  @Prop EXHIBIT: string
  currentIndex: number = 0
  @State contentWidth: number = 0

  private gridCoverWidth(): number {
    return this.contentWidth > 0 ?
      Math.max(1, Math.min(100, this.contentWidth / AdaptiveLayout.shelfColumns(this.contentWidth) - 16)) : 100
  }

  @State changeNumber: number = 0
  @State isShowBookFolderInfoDialog: boolean = false
  @StorageLink('BOOK_IS_BOOK_GROUPS_REFRESHING') @Watch('getGroupList') BOOK_IS_BOOK_GROUPS_REFRESHING: number = 0

  aboutToAppear(): void {
    this.getGroupList()
  }

  @State groupList: BookGroups[] = []

  getGroupList() {
    BookGroupsDao.search({
      type: this.currentIndex
    }).then((val) => {
      this.groupList = val
    })
  }

  build() {
    GridRow({
      columns: this.EXHIBIT === '宫格' ? AdaptiveLayout.shelfColumns(this.contentWidth) : 1
    }) {
      ForEach(this.groupList, (item: BookGroups) => {
        if (item.show && !item.isSystem) {
          GridCol() {
            Column() {
              if (this.EXHIBIT === '宫格') {
                this.bookInfoGrid(item)
              } else {
                this.bookFolderInfo(item)
              }
            }
          }
          .gesture(
            LongPressGesture({ repeat: false, duration: 500 })
              .onAction((event: GestureEvent) => {
                this.dialogGroupData = item
                this.changeNumber = 1
                this.openGroupInfoDialog()
              }))
          .onClick(() => {
            this.isShowBookFolderInfoDialog = true
            this.clickGroup = item
          })
        }
      })
    }
    .width('100%')
    .onAreaChange((_oldArea: Area, area: Area) => {
      this.contentWidth = Number(area.width)
    })
    .bindSheet($$this.isShowBookFolderInfoDialog, this.bookFolderInfoDialog(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE, 200],
      showClose: false,
      dragBar: true,
      maskColor: 'rgba(0,0,0,0.6)',
      onDisappear: () => {
      }
    })
  }

  @Prop clickGroup: BookGroups

  @Builder
  bookFolderInfoDialog() {
    Column() {
      BookManageDialog({
        title: this.clickGroup.groupName,
        currentIndex: this.currentIndex,
        bookTypeNumber: this.clickGroup.groupId,
      })
    }
  }

  @Builder
  bookInfoGrid(item: BookGroups) {
    Column({
      space: 5
    }) {
      Column() {
        Column() {
          Stack() {
            Stack() {
              Stack() {
                if (item.isTop) {
                  Text('置顶')
                    .fontColor(Color.White)
                    .fontWeight(300)
                    .fontSize(8)
                    .padding(3)
                    .borderRadius(5)
                    .backgroundColor('rgba(0, 0, 0, 0.45)')
                    .zIndex(1)
                }
                Image(BookCoverLogic.displaySource(item.coverUrl, $r('app.media.icon_book_default_cover_one')))
                  .draggable(false)
                  .alt($r('app.media.icon_book_default_cover_one'))
                  .width(this.gridCoverWidth() * 0.88)
                  .height(this.gridCoverWidth() * 1.2)
              }.alignContent(Alignment.BottomStart)
            }
            .zIndex(2)

            if (item.coverType !== 2) {
              Row() {
                Image($r('app.media.occlusion1')).draggable(false)
              }
              .zIndex(1)
              .width(this.gridCoverWidth() * 0.95).height(this.gridCoverWidth() * 1.1)

              Row() {
                Image($r('app.media.occlusion2'))
              }.zIndex(0)
              .width(this.gridCoverWidth()).height(this.gridCoverWidth())
            }
          }
          .align(Alignment.BottomStart)
        }

        Row().width(this.gridCoverWidth()).height(20).backgroundColor('rgba(255, 255, 255, 0.6)').borderRadius(10)
      }

      Text(item.groupName)
        .fontSize(15)
        .fontWeight(700)
        .textOverflow({
          overflow: TextOverflow.Ellipsis
        })
        .ellipsisMode(EllipsisMode.END)
        .maxLines(2)
      Text(`共${item.bookIds?.length || 0}本`)
        .fontSize(12)
        .fontColor('rgb(174,174,174)')
        .textOverflow({
          overflow: TextOverflow.Ellipsis
        })
        .ellipsisMode(EllipsisMode.END)
        .fontWeight(500)
        .maxLines(1)
    }
    .width(this.gridCoverWidth() + 16)
    .borderRadius(8)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 8,
      right: 8,
      bottom: 5,
      top: 5
    })
  }

  @Builder
  bookFolderInfo(group: BookGroups) {
    Flex(
      {
        alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.SpaceBetween
      }
    ) {
      Row({
        space: 20
      }) {
        BookOverlay({
          bookImage: group.coverUrl,
          isTop: group.isTop,
          coverType: group.coverType
        })
        Column({
          space: 24
        }) {
          Text(group.groupName)
            .fontWeight(700)
          Column() {
            Text(`共${group.bookIds?.length || 0}本`)
              .fontSize(12)
              .fontColor('rgb(174,174,174)')
              .textOverflow({
                overflow: TextOverflow.Ellipsis
              })
              .ellipsisMode(EllipsisMode.END)
              .fontWeight(400)
              .maxLines(1)
              .lineHeight(20)
            // Text(group.newUpdateBook?group.newUpdateBook:'暂无更新')
            //   .fontSize(12)
            //   .fontWeight(400)
            //   .textOverflow({
            //     overflow:TextOverflow.Ellipsis
            //   })
            //   .ellipsisMode(EllipsisMode.END)
            //   .maxLines(1)
            //   .lineHeight(20)
          }
          .width('60%')
          .alignItems(HorizontalAlign.Start)
        }
        .alignItems(HorizontalAlign.Start)
      }
    }
    .padding(10)
    .borderRadius(10)
  }

  @State dialogGroupData: BookGroups = new BookGroups()
  groupInfoDialog: CustomDialogController | null = null

  private openGroupInfoDialog(): void {
    // 控制器跟随窗口宽度，主体根组件限宽并居中，分屏时无需关闭弹窗。
    this.groupInfoDialog = new CustomDialogController({
      builder: FolderInfoDialog({
        itemData: this.dialogGroupData,
        cancel: () => {
          this.exitDialog()
        }
      }),
      cancel: this.exitDialog,
      autoCancel: true,
      width: '100%',
      alignment: DialogAlignment.Bottom,
      customStyle: true

    })
    this.groupInfoDialog.open()
  }

  //退出弹框
  exitDialog() {
    this.changeNumber = 0
    this.groupInfoDialog?.close()
  }
}