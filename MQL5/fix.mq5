//+------------------------------------------------------------------+
//|                                      AutoHedgeFullAveraging.mq5  |
//+------------------------------------------------------------------+
#property strict

//Dapat Dirubah 
input double LotSize = 0.01;  //Besar Lot Transaksi (0.01)
input int TakeProfitPoints = 10;  //Batas Auto Stop Profit (10))
input int selisih = 20; //Selisih batas pembelian ulang (20))

input int jml_batas = 10; //jumlah transaksi (10)
double kesimpulan_stop = 100; //batas sel dan buy (100)

int sisi_kiri = 300;
int sisi_atas = 10;

//===================================
input int Slippage = 10;
input ulong MagicNumber = 445566;

//Posisi BUY/SELL
double posisi_buy = 0.0;
double posisi_sell = 0.0;


int kesimpulan = 1;


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
            
            if(i==0){
               posisi_sell = PositionGetDouble(POSITION_PRICE_OPEN);
            }
            sellCount++;
            
         }
      }
      
   }
   
   //Variabel Awal
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp_buy = ask + TakeProfitPoints * _Point;
   double tp_sell = bid - TakeProfitPoints * _Point;
   
   double selisih_buy = ((posisi_buy - bid) / _Point);
   double selisih_sell = ((ask - posisi_sell) / _Point);
   double selisih_kesimpulan = MathAbs(posisi_sell - posisi_buy) / _Point;
   
   double currentProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double saldo = AccountInfoDouble(ACCOUNT_BALANCE);
   
   //TAMPILAN
   
   TampilkanTeks("posisi_buy","POSISI BUY : " + DoubleToString(posisi_buy / _Point,0), sisi_kiri, sisi_atas);
   TampilkanTeks("selisih","SELISIH BUY : " + DoubleToString(selisih_buy,0), sisi_kiri, sisi_atas+20);
   TampilkanTeks("jml_buy","JML BUY AKTIF : " + DoubleToString((buyCount),0), sisi_kiri, sisi_atas+40);
   
   TampilkanTeks("posisi_sell","POSISI SELL : " + DoubleToString(posisi_sell / _Point,0), sisi_kiri, sisi_atas+80);
   TampilkanTeks("selisih_sell","SELISIH SELL : " + DoubleToString(selisih_sell,0), sisi_kiri, sisi_atas+100);
   TampilkanTeks("jml_sel","JML SEL AKTIF : " + DoubleToString((sellCount),0), sisi_kiri, sisi_atas+120);
   TampilkanTeks("jml_batas","JML BATAS TRANSAKSI : " + IntegerToString((jml_batas),0), sisi_kiri, sisi_atas+160);
   
   TampilkanTeks("selisih_kesimpulan","SELISIH KESIMPULAN : " + DoubleToString((selisih_kesimpulan),0), sisi_kiri, sisi_atas+180);
   TampilkanTeks("stop_kesimpulan","STOP KESIMPULAN : " + DoubleToString((kesimpulan_stop),0), sisi_kiri, sisi_atas+200);
   
   
   //PROSES BUY
   if(kesimpulan==1){
      if(buyCount < jml_batas){
         if(buyCount < 1){
            OpenBuy(ask, tp_buy);
            return;
         }else{
            if((selisih_buy) >= selisih){
               OpenBuy(ask, tp_buy);
               return;
            }
         }
      }
      
      //PROSES SELL
      
      if(sellCount < jml_batas){
         if(sellCount < 1){
            OpenSell(bid, tp_sell);
            return;
         }else{
            if((selisih_sell) >= selisih){
               OpenSell(bid, tp_sell);
               return;
            }
         }
      }
   }
   
   
   //Pengecekan Kesimpulan
   if(selisih_kesimpulan >= kesimpulan_stop){
      kesimpulan=0;
   }
   
   if((MathAbs(posisi_buy-posisi_sell)/ _Point) <= selisih){
      kesimpulan=1;
   }
   
   if(buyCount == 0 && sellCount == 0){
      kesimpulan=1;
   }
   
   if(kesimpulan==1){
      TampilkanTeks("kesimpulan","KESIMPULAN : BERJALAN", sisi_kiri, sisi_atas+220);
   }else{
      TampilkanTeks("kesimpulan","KESIMPULAN : STOP", sisi_kiri, sisi_atas+220);
   }
   
   TampilkanTeks("tp","TAKE PROFIT : " + IntegerToString(TakeProfitPoints), sisi_kiri, sisi_atas+260);
    
   TampilkanTeks("ls","LOTSIZE : " + DoubleToString(LotSize, 2), sisi_kiri, sisi_atas+280);
   TampilkanTeks("pembelian_ulang","PEMBELIAN ULANG : " + IntegerToString(selisih), sisi_kiri, sisi_atas+300);
   
   TampilkanTeks("profit","PROFIT : " + DoubleToString(currentProfit, 2), sisi_kiri, sisi_atas+340);
   TampilkanTeks("equity","EKUITI : " + DoubleToString(equity, 2), sisi_kiri, sisi_atas+360);
   TampilkanTeks("margin","MARGIN : " + DoubleToString(margin, 2), sisi_kiri, sisi_atas+380);
   TampilkanTeks("saldo","SALDO : " + DoubleToString(saldo, 2), sisi_kiri, sisi_atas+400);
   TampilkanTeks("jml_transaksi","JML TRANSAKSI : " + IntegerToString(buyCount+sellCount), sisi_kiri, sisi_atas+420);
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