#include <..\Experts\newsBT\newsDownloader.mqh>;

void OnInit(){
    downloadCountryNews("US");
    downloadNews();
}
