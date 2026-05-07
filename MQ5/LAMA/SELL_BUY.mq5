//+------------------------------------------------------------------+
//|                                      AutoHedgeFullAveraging.mq5  |
//+------------------------------------------------------------------+
#property strict

//Dapat Dirubah 
input int jenis = 2; //1 BUY, 2 SELL

input double LotSize = 0.01;  //Besar Lot Transaksi (0.01)
input int TakeProfitPoints = 10;  //Batas Auto Stop Profit (10))
input int selisih = 20; //Selisih batas pembelian ulang (10))

input int jml_transaksi = 2; //jumlah transaksi (2)

int sisi_kiri = 300;
int sisi_atas = 10;

//===================================
input int Slippage = 10;
input ulong MagicNumber = 445566;

int kesimpulan = 1;

//Posisi BUY/SELL
double posisi_buy = 0.0;
double posisi_sell = 0.0;
int proses_transaksi = 0;


//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------
// Fungsi untuk menampilkan teks ke chart
void TampilkanTeks(string nama, string isi_teks, int atas, int kiri)
  {
   string nama_objek = nama;
   
   if (ObjectFind(0, nama_objek) >= 0)
     ObjectDelete(0, nama_objek);

   if(ObjectCreate(0, nama_objek, OBJ_LABEL, 0, 0, 0))
     {
      ObjectSetInteger(0, nama_objek, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nama_objek, OBJPROP_XDISTANCE, atas);
      ObjectSetInteger(0, nama_objek, OBJPROP_YDISTANCE, kiri);
      ObjectSetInteger(0, nama_objek, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, nama_objek, OBJPROP_COLOR, clrWhiteSmoke);
      ObjectSetString(0, nama_objek, OBJPROP_TEXT, isi_teks);
     }
   else
     {
      Print("Gagal membuat label teks.");
     }
  }

  
  
void OnTick()
{
   int buyCount = 0;
   int sellCount = 0;

   // Hitung jumlah posisi aktif BUY dan SELL dengan magic number EA ini
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (PositionGetTicket(i) > 0 &&
          PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber)
      {
         int type = (int)PositionGetInteger(POSITION_TYPE);
         if (type == POSITION_TYPE_BUY){
            posisi_buy = PositionGetDouble(POSITION_PRICE_OPEN);
            buyCount++;
            
         }else if (type == POSITION_TYPE_SELL){
            posisi_sell = PositionGetDouble(POSITION_PRICE_OPEN);
            sellCount++;
         }
      }
      
   }
   
   //Variabel Awal
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp_buy = ask + TakeProfitPoints * _Point;
   double tp_sell = bid - TakeProfitPoints * _Point;
   
   double currentProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double saldo = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double selisih_buy = ((posisi_buy - bid) / _Point);
   double selisih_sell = ((ask - posisi_sell) / _Point);
   
   //TAMPILAN
   if(jenis==1){
      TampilkanTeks("posisi","POSISI : " + DoubleToString(posisi_buy / _Point,0), sisi_kiri, sisi_atas);
      TampilkanTeks("selisih","SELISIH : " + DoubleToString(selisih_buy,0), sisi_kiri, sisi_atas+20);
      TampilkanTeks("jml_transaksi","JML TRANSAKSI AKTIF : " + DoubleToString((buyCount),0), sisi_kiri, sisi_atas+40);
      
      TampilkanTeks("jml_batas","JML BATAS TRANSAKSI : " + IntegerToString((jml_transaksi),0), sisi_kiri, sisi_atas+80);
   }else{
      TampilkanTeks("posisi","POSISI : " + DoubleToString(posisi_sell / _Point,0), sisi_kiri, sisi_atas);
      TampilkanTeks("selisih","SELISIH : " + DoubleToString(selisih_sell,0), sisi_kiri, sisi_atas+20);
      TampilkanTeks("jml_transaksi","JML TRANSAKSI AKTIF : " + DoubleToString((sellCount),0), sisi_kiri, sisi_atas+40);
      
      TampilkanTeks("jml_batas","JML BATAS TRANSAKSI : " + IntegerToString((jml_transaksi),0), sisi_kiri, sisi_atas+80);
      
   }
   
   
   
   //PROSES BUY
   if(kesimpulan==1){
      if(jenis == 1){
         if(buyCount < 1){
            OpenBuy(ask, tp_buy);
            return;
         }else{
            if((selisih_buy) >= selisih && buyCount  < jml_transaksi ){
               OpenBuy(ask, tp_buy);
               return;
            }
         }
      }
      
      //PROSES SELL
      if(jenis == 2){
         if(sellCount < 1){
            OpenSell(bid, tp_sell);
            return;
         }else{
            if((selisih_sell) >= selisih && sellCount < jml_transaksi){
               OpenSell(bid, tp_sell);
               return;
            }
         }
      }
   }
   
   //Menetapkan Kondisi Awal Buy dan Sell
   if(proses_transaksi==0){
      posisi_buy = ask;
      posisi_sell = bid;
   }
   
   
   //Pengecekan Kesimpulan
   //if(proses_transaksi >= jml_transaksi){
   //   kesimpulan=0;
   //}
   
   
   //if(kesimpulan==1){
   //   TampilkanTeks("kesimpulan","PROSES TRANSAKSI : BERJALAN", sisi_kiri, sisi_atas+120);
   //}else{
   //   TampilkanTeks("kesimpulan","PROSES TRANSAKSI : STOP", sisi_kiri, sisi_atas+120);
   //}
   
   TampilkanTeks("tp","TAKE PROFIT : " + IntegerToString(TakeProfitPoints), sisi_kiri, sisi_atas+110);
   TampilkanTeks("ls","LOTSIZE : " + DoubleToString(LotSize, 2), sisi_kiri, sisi_atas+130);
   TampilkanTeks("pembelian_ulang","PEMBELIAN ULANG : " + IntegerToString(selisih), sisi_kiri, sisi_atas+150);
   
   TampilkanTeks("profit","PROFIT : " + DoubleToString(currentProfit, 2), sisi_kiri, sisi_atas+180);
   TampilkanTeks("equity","EKUITI : " + DoubleToString(equity, 2), sisi_kiri, sisi_atas+200);
   TampilkanTeks("margin","MARGIN : " + DoubleToString(margin, 2), sisi_kiri, sisi_atas+220);
   TampilkanTeks("saldo","SALDO : " + DoubleToString(saldo, 2), sisi_kiri, sisi_atas+240);
   if(jenis == 1){
      TampilkanTeks("jenis_transaksi","JENIS TRANSAKSI : BUY ", sisi_kiri, sisi_atas+260);
   }else{
      TampilkanTeks("jenis_transaksi","JENIS TRANSAKSI : SELL ", sisi_kiri, sisi_atas+260);
   }
}

//+------------------------------------------------------------------+
//| Fungsi membuka posisi BUY                                       |
//+------------------------------------------------------------------+
void OpenBuy(double ask, double tp)
{
   posisi_buy = ask;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoBuy";

   OrderSend(request, result);
}

void OpenSell(double bid, double tp)
{
   posisi_sell = bid;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.tp = tp;
   request.deviation = Slippage;
   request.magic = MagicNumber;
   request.comment = "AutoBuy";

   OrderSend(request, result);
}