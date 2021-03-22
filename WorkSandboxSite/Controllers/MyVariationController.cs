using EPiServer;
using EPiServer.Core;
using EPiServer.Framework.DataAnnotations;
using EPiServer.Web.Mvc;
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;
using WorkSandboxSite.Models.Catalog;

namespace WorkSandboxSite.Controllers
{
    public class MyVariationController : ContentController<MyVariation>
    {
        public ActionResult Index(MyVariation currentPage)
        {
            /* Implementation of action. You can create your own view model class that you pass to the view or
             * you can pass the page type for simpler templates */

            return View(currentPage);
        }
    }
}